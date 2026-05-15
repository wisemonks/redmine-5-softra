require File.dirname(__FILE__) + '/lib/redmine_ai_formatter_hook_listener'

Redmine::Plugin.register :redmine_ai_formatter do
  name 'Redmine AI Text Formatter'
  author 'Wisemonks'
  author_url 'https://wisemonks.com'
  description 'AI-powered text formatting for CommonMark Markdown conversion'
  version '0.1.0'
end

unless SettingsHelper.include?(AiFormatterSettingsHelperPatch)
  SettingsHelper.send(:include, AiFormatterSettingsHelperPatch)
end
