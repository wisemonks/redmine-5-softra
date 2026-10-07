class CustomerIssueDueDateReassignment
  def self.call
    new.call
  end

  def call
    overdue_issues.find_each do |issue|
      reassign(issue)
    end
  end

  private

  def overdue_issues
    Issue.where(closed_on: nil).
      where('due_date < ?', Date.current).
      where.not(assigned_to_id: nil)
  end

  def reassign(issue)
    return unless customer_or_contractor?(issue.assigned_to, issue.project)

    target = target_user(issue)
    return if target.nil? || customer_or_contractor?(target, issue.project)

    previous_assignee_id = issue.assigned_to_id
    issue.update_column(:assigned_to_id, target.id)

    journal = issue.journals.build(:user => journal_user(issue))
    journal.details.build(
      :property => 'attr',
      :prop_key => 'assigned_to_id',
      :old_value => previous_assignee_id,
      :value => target.id
    )
    journal.save!
  end

  def target_user(issue)
    assignment = assignment_to_current_assignee(issue)
    return issue.author if assignment.nil? || assignment.detail.old_value.blank?

    latest_comment_author(issue) || assignment.journal.user || issue.author
  end

  def assignment_to_current_assignee(issue)
    journal = issue.journals.
      where(:private_notes => false).
      joins(:details).
      where(:journal_details => {
        :property => 'attr',
        :prop_key => 'assigned_to_id',
        :value => issue.assigned_to_id.to_s
      }).
      order(:id => :desc).
      first
    return if journal.nil?

    detail = journal.details.find do |candidate|
      candidate.property == 'attr' &&
        candidate.prop_key == 'assigned_to_id' &&
        candidate.value == issue.assigned_to_id.to_s
    end
    return if detail.nil?

    Struct.new(:journal, :detail).new(journal, detail)
  end

  def latest_comment_author(issue)
    issue.journals.
      where(:private_notes => false).
      where.not(:user_id => issue.assigned_to_id).
      where.not(:notes => [nil, '']).
      order(:id => :desc).
      find do |journal|
        journal.user.present? && !customer_or_contractor?(journal.user, issue.project)
      end&.user
  end

  def customer_or_contractor?(user, project)
    project_member = project&.members&.find_by(:user_id => user&.id)
    project_member.present? && project_member.roles.where(:name => %w[Customer Contractor]).exists?
  end

  def journal_user(issue)
    User.current || User.anonymous || issue.author
  end
end
