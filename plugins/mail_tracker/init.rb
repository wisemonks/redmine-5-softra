Redmine::Plugin.register :mail_tracker do
  name 'Mail Tracker plugin'
  author 'Wisemonks'
  author_url 'https://wisemonks.com'
  description 'Real time email fetch for issue coordination'
  version '1.0.3'

  settings :default => {
    :allowed_users => User.table_exists? ? User.where(["users.login IS NOT NULL AND users.login <> ''"]).collect {|x| x.id.to_s} : [] },
    :partial => 'settings/mail_tracker_settings'
end

Rails.configuration.after_initialize do
  Project.send(:include, RedmineProjectSpecificEmailSender::ProjectPatch)
  Mailer.send(:include, RedmineProjectSpecificEmailSender::MailerPatch)
  ProjectsHelper.send(:include, RedmineProjectSpecificEmailSender::ProjectsHelperPatch)
end

# ActionMailer::Base.register_interceptor(RedmineProjectSpecificEmailSender::Interceptor)