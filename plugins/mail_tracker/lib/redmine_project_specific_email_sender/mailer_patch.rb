module RedmineProjectSpecificEmailSender
  module MailerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :mail, :mail_with_project_specific_email
        alias_method :mail_without_project_specific_email, :mail

        alias_method :issue_add, :issue_add_with_project_specific_email
        alias_method :issue_add_without_project_specific_email, :issue_add

        alias_method :issue_edit, :issue_edit_with_project_specific_email
        alias_method :issue_edit_without_project_specific_email, :issue_edit

        alias_method :document_added, :document_added_with_project_specific_email
        alias_method :document_added_without_project_specific_email, :document_added

        alias_method :attachments_added, :attachments_added_with_project_specific_email
        alias_method :attachments_added_without_project_specific_email, :attachments_added

        alias_method :news_added, :news_added_with_project_specific_email
        alias_method :news_added_without_project_specific_email, :news_added

        alias_method :message_posted, :message_posted_with_project_specific_email
        alias_method :message_posted_without_project_specific_email, :message_posted

        alias_method :wiki_content_added, :wiki_content_added_with_project_specific_email
        alias_method :wiki_content_added_without_project_specific_email, :wiki_content_added

        alias_method :wiki_content_updated, :wiki_content_updated_with_project_specific_email
        alias_method :wiki_content_updated_without_project_specific_email, :wiki_content_updated
      end
    end

    module InstanceMethods
      def mail_with_project_specific_email(headers={})
        if (@project)
          headers['X-Redmine-Project-Specific-Sender'] = @project.email
        end
        @issue_url = @issue_url_by_project if @issue_url_by_project
        mail_without_project_specific_email(headers)
      end

      def issue_add_with_project_specific_email(*args)
        @project = args.first.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first, :host => @project.crm_host_name)
        issue_add_without_project_specific_email(*args)
      end

      def issue_edit_with_project_specific_email(*args)
        @project = args.first.journalized.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first.journalized, :anchor => "change-#{args.first.id}", :host => @project.crm_host_name)
        issue_edit_without_project_specific_email(*args)
      end

      def document_added_with_project_specific_email(*args)
        @project = args.first.project
        document_added_without_project_specific_email(*args)
      end

      def attachments_added_with_project_specific_email(*args)
        @project = args.first.first.container.project
        attachments_added_without_project_specific_email(*args)
      end

      def news_added_with_project_specific_email(*args)
        @project = args.first.project
        news_added_without_project_specific_email(*args)
      end

      def message_posted_with_project_specific_email(*args)
        @project = args.first.board.project
        message_posted_without_project_specific_email(*args)
      end

      def wiki_content_added_with_project_specific_email(*args)
        @project = args.first.project
        wiki_content_added_without_project_specific_email(*args)
      end

      def wiki_content_updated_with_project_specific_email(*args)
        @project = args.first.project
        wiki_content_updated_without_project_specific_email(*args)
      end
    end
  end
end
