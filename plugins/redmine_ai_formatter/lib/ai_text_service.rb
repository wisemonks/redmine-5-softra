# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class AiTextService
  class AiError < StandardError; end

  def initialize
  end

  def format_text(text, custom_prompt: nil)
    validate_settings!

    prompt = custom_prompt.presence || default_prompt
    api_url = Setting.ai_api_url.to_s.chomp('/')
    endpoint = "#{api_url}/chat/completions"

    body = {
      model: Setting.ai_model,
      messages: [
        { role: 'system', content: prompt },
        { role: 'user', content: text }
      ],
      temperature: (Setting.ai_temperature.presence || '0.1').to_f
    }

    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{Setting.ai_api_key}"
    request.body = body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      error_body = begin
        JSON.parse(response.body)
      rescue
        { 'error' => { 'message' => response.body } }
      end
      error_msg = error_body.dig('error', 'message') || response.body
      raise AiError, "AI API error (#{response.code}): #{error_msg}"
    end

    result = JSON.parse(response.body)
    content = result.dig('choices', 0, 'message', 'content')
    raise AiError, "Unexpected AI API response format" unless content

    content.strip
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise AiError, "AI API request timed out after #{timeout_seconds}s"
  rescue Errno::ECONNREFUSED, SocketError => e
    raise AiError, "Could not connect to AI API: #{e.message}"
  end

  private

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
    (Setting.ai_request_timeout.presence || '30').to_i
  end
end
