# frozen_string_literal: true

require 'ruby_llm'

class AiTextService
  class AiError < StandardError; end

  def format_text(text, custom_prompt: nil)
    validate_settings!
    configure_ruby_llm!

    prompt = custom_prompt.presence || default_prompt
    temperature = (Setting.ai_temperature.presence || '0.1').to_f

    chat = RubyLLM.chat(model: Setting.ai_model, provider: :openai, assume_model_exists: true)
    chat.with_instructions(prompt)
    chat.with_temperature(temperature)

    response = chat.ask(text)
    content = response.content
    raise AiError, "Empty response from AI" if content.blank?

    content.strip
  rescue RubyLLM::Error => e
    raise AiError, "AI API error: #{e.message}"
  rescue Faraday::TimeoutError
    raise AiError, "AI API request timed out after #{timeout_seconds}s"
  rescue Faraday::ConnectionFailed => e
    raise AiError, "Could not connect to AI API: #{e.message}"
  end

  private

  def configure_ruby_llm!
    api_url = Setting.ai_api_url.to_s.chomp('/')

    RubyLLM.configure do |config|
      config.openai_api_key = Setting.ai_api_key.to_s
      config.openai_api_base = api_url
      config.request_timeout = timeout_seconds
    end
  end

  def validate_settings!
    raise AiError, "AI API URL is not configured" if Setting.ai_api_url.blank?
    raise AiError, "AI API Key is not configured" if Setting.ai_api_key.blank?
    raise AiError, "AI Model is not configured" if Setting.ai_model.blank?
  end

  def default_prompt
    Setting.ai_default_prompt.presence ||
      'You are a text formatting assistant. Convert the following text to proper CommonMark Markdown. Fix any formatting issues, preserve the original meaning and content. Return ONLY the formatted text, no explanations.'
  end

  def timeout_seconds
    (Setting.ai_request_timeout.presence || '120').to_i
  end
end
