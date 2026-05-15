module JournalPatch
  def self.included(base)
    base.class_eval do
      alias_method :notified_watchers_without_child_filter, :notified_watchers
      alias_method :notified_users_without_child_filter, :notified_users
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
        project_member = issue.project.members.find_by(user_id: issue.assigned_to_id)
        customer_or_contractor = project_member&.roles&.where('roles.name in (?)', %w[Customer Contractor])
        return if customer_or_contractor.nil? || customer_or_contractor.empty?

        recent_non_customer_edit = issue.journals.where.not(user_id: issue.assigned_to_id, private_notes: true).order(id: :desc)&.first&.user_id
        recent_non_customer_edit = issue.author_id if recent_non_customer_edit.nil?
        return if recent_non_customer_edit != issue.assigned_to_id

        issue.assigned_to_id = recent_non_customer_edit
        issue.save
      end

      def notified_watchers
        notified = notified_watchers_without_child_filter
        filter_by_child_visibility(notified)
      end

      def notified_users
        notified = notified_users_without_child_filter
        filter_by_child_visibility(notified)
      end

      # def notified_mentions
      #   notified = notified_mentions_without_child_filter
      #   filter_by_child_visibility(notified)
      # end

      private

      def filter_by_child_visibility(notified)

        # Check for both child_id changes AND relation additions
        child_detail = details.detect { |d| (d.property == 'attr' && d.prop_key == 'child_id') ||
                                            (d.property == 'relation' && d.prop_key == 'relates') }

        if child_detail
          # Get the child issue ID from different sources
          child_id = if child_detail.property == 'relation'
                       child_detail.value.presence || child_detail.old_value.presence  # For relations (both additions and removals)
                     else
                       child_detail.value.presence || child_detail.old_value.presence  # For child_id
                     end

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
    end
  end
end