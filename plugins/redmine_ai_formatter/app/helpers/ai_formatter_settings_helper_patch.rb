# frozen_string_literal: true

module AiFormatterSettingsHelperPatch
  def self.included(base)
    base.class_eval do
      unless method_defined?(:administration_settings_tabs_without_ai)
        alias_method :administration_settings_tabs_without_ai, :administration_settings_tabs

        def administration_settings_tabs
          tabs = administration_settings_tabs_without_ai
          # Avoid adding duplicate AI tab
          return tabs if tabs.any? { |t| t[:name] == 'ai' }

          ai_tab = {
            name: 'ai',
            partial: 'settings/ai',
            label: :label_ai_settings
          }
          api_index = tabs.index { |t| t[:name] == 'api' }
          if api_index
            tabs.insert(api_index, ai_tab)
          else
            tabs << ai_tab
          end
          tabs
        end
      end
    end
  end
end
