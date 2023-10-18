module RedmineProjectSpecificEmailSender
  module MailerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      def mail(headers={})
        if (@project)
          headers['X-Redmine-Project-Specific-Sender'] = @project.email
        end
        @issue_url = @issue_url_by_project if @issue_url_by_project
      end

      def issue_add(*args)
        @project = args.last.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first, :host => @project.crm_host_name)
      end

      def issue_edit(*args)
        @project = args.last.journalized.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.last.journalized, :anchor => "change-#{args.last.id}", :host => @project.crm_host_name)
      end

      def document_added(*args)
        @project = args.last.project
      end

      def attachments_added(*args)
        @project = args.last.first.container.project
      end

      def news_added(*args)
        @project = args.last.project
      end

      def message_posted(*args)
        @project = args.last.board.project
      end

      def wiki_content_added(*args)
        @project = args.last.project
      end

      def wiki_content_updated(*args)
        @project = args.last.project
      end
    end
  end
end
