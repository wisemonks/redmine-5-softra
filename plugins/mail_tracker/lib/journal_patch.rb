module JournalPatch
  def self.included(base)
    base.class_eval do
      alias_method :notified_watchers_without_child_filter, :notified_watchers
      alias_method :notified_users_without_child_filter, :notified_users
      alias_method :notified_mentions_without_child_filter, :notified_mentions
      # alias_method :notified_users_without_child_filter, :notified_users
      # alias_method :notified_mentions_without_child_filter, :notified_mentions

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
        return if private_notes? || user_id != issue.assigned_to_id
        return unless customer_or_contractor_assignee?

        assignment_journal = issue.journals.
          where(:private_notes => false).
          joins(:details).
          where(:journal_details => {
            :property => 'attr',
            :prop_key => 'assigned_to_id',
            :value => issue.assigned_to_id.to_s
          }).
          where.not(:user_id => issue.assigned_to_id).
          order(:id => :desc).
          first
        previous_assignee = assignment_journal&.user
        previous_assignee ||= issue.author if issue.author_id != issue.assigned_to_id
        return if previous_assignee.nil? || customer_or_contractor?(previous_assignee)

        previous_assignee_id = issue.assigned_to_id
        issue.update_column(:assigned_to_id, previous_assignee.id)
        reassignment_journal = issue.journals.build(:user => user)
        reassignment_journal.details.build(
          :property => 'attr',
          :prop_key => 'assigned_to_id',
          :old_value => previous_assignee_id,
          :value => previous_assignee.id
        )
        reassignment_journal.save!
      end

      private

      def customer_or_contractor_assignee?
        customer_or_contractor?(issue.assigned_to)
      end

      def customer_or_contractor?(user)
        member = issue.project.members.find_by(:user_id => user&.id)
        member.present? && member.roles.where(:name => %w[Customer Contractor]).exists?
      end

      public

      def notified_watchers
        notified = notified_watchers_without_child_filter
      #   filter_by_child_visibility(notified)
      # end

      # def notified_users
      #   notified = notified_users_without_child_filter
      #   filter_by_child_visibility(notified)
      # end

      # def notified_mentions
      #   notified = notified_mentions_without_child_filter
      #   filter_by_child_visibility(notified)
      # end

      # private

      # def filter_by_child_visibility(notified)
        # Check if this journal is about adding/removing a child issue
        child_detail = details.detect { |d| d.property == 'attr' && d.prop_key == 'child_id' }
        
        if child_detail
          # Get the child issue ID (from value if added, old_value if removed)
          child_id = child_detail.value.presence || child_detail.old_value.presence
          
          if child_id
            child_issue = Issue.find_by(id: child_id)
            
            # Filter out users who cannot view the child issue
            if child_issue
              notified.select! { |user| child_issue.visible?(user) }
            end
          end
        end
        
        notified
      end

      def notified_users
        filter_by_child_visibility(notified_users_without_child_filter)
      end

      def notified_mentions
        filter_by_child_visibility(notified_mentions_without_child_filter)
      end

      private

      def filter_by_child_visibility(notified)
        child_detail = details.detect { |d| d.property == 'attr' && d.prop_key == 'child_id' }
        return notified unless child_detail

        child_id = child_detail.value.presence || child_detail.old_value.presence
        child_issue = Issue.find_by(id: child_id) if child_id
        notified.select! { |user| child_issue.visible?(user) } if child_issue
        notified
      end
    end
  end
end