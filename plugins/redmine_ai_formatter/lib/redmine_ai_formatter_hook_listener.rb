class RedmineAiFormatterHookListener < Redmine::Hook::ViewListener
  render_on :view_layouts_base_html_head, partial: 'redmine_ai_formatter/html_head'
end
