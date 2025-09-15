module JournalPatch
  def self.included(base)
    base.class_eval do
      after_create :reassign_from_customer_or_contractor
      
      scope :visible, lambda {|*args|
        user = args.shift || User.current
        options = args.shift || {}

        joins(:issue => :project).
          joins("LEFT OUTER JOIN watchers wa ON wa.watchable_id = #{Issue.table_name}.id AND wa.watchable_type = 'Issue'").
          where(Issue.visible_condition(user, options)).
          where(Journal.visible_notes_condition(user, :skip_pre_condition => true))
      }
      
      def reassign_from_customer_or_contractor
        project_member = issue.project.members.find_by(user_id: issue.assigned_to_id)
        customer_or_contractor = project_member&.roles&.where('roles.name in (?)', %w[Customer Contractor])
        return if customer_or_contractor.nil? || customer_or_contractor.empty?

        recent_non_customer_edit = issue.journals.where.not(user_id: issue.assigned_to_id, private_notes: true).order(id: :desc)&.first&.user_id
        recent_non_customer_edit = issue.author_id if recent_non_customer_edit.nil?
        return if recent_non_customer_edit != issue.assigned_to_id

        issue.assigned_to_id = recent_non_customer_edit
        issue.save
      end
    end
  end
end