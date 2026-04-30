# frozen_string_literal: true

class AiFormatterController < ApplicationController
  before_action :require_login

  def format_text
    text = params[:text].to_s
    custom_prompt = params[:custom_prompt].presence

    if text.blank?
      render json: { error: 'No text provided' }, status: :unprocessable_entity
      return
    end

    service = AiTextService.new
    formatted = service.format_text(text, custom_prompt: custom_prompt)

    render json: { formatted_text: formatted }
  rescue AiTextService::AiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "AI Formatter error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
  end
end
