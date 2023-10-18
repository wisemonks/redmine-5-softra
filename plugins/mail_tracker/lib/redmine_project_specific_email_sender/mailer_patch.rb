module RedmineProjectSpecificEmailSender
  module MailerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      def mail(headers={})
        super
        if (@project)
          headers['X-Redmine-Project-Specific-Sender'] = @project.email
        end
        @issue_url = @issue_url_by_project if @issue_url_by_project
        # mail_without_project_specific_email(headers)
      end

      def issue_add(*args)
        @project = args.last.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first, :host => @project.crm_host_name)
        super
        # issue_add_without_project_specific_email(*args)
      end

      def issue_edit(*args)
        @project = args.first.journalized.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first.journalized, :anchor => "change-#{args.first.id}", :host => @project.crm_host_name)
        super
        # issue_edit_without_project_specific_email(*args)
      end

      def document_added(*args)
        @project = args.first.project
        super
        # document_added_without_project_specific_email(*args)
      end

      def attachments_added(*args)
        @project = args.first.first.container.project
        super
        # attachments_added_without_project_specific_email(*args)
      end

      def news_added(*args)
        @project = args.first.project
        super
        # news_added_without_project_specific_email(*args)
      end

      def message_posted(*args)
        @project = args.first.board.project
        super
        # message_posted_without_project_specific_email(*args)
      end

      def wiki_content_added(*args)
        @project = args.first.project
        super
        # wiki_content_added_without_project_specific_email(*args)
      end

      def wiki_content_updated(*args)
        @project = args.first.project
        super
        # wiki_content_updated_without_project_specific_email(*args)
      end
    end
  end
end
