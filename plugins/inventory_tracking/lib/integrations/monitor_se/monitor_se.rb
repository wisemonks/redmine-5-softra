require 'httparty'
require_relative 'endpoints/parts'
require_relative 'endpoints/stock_balance_changes'
require_relative 'endpoints/physical_inventory_lists'
require_relative 'endpoints/inventory_commands'
require_relative 'endpoints/quantity_changes'

require 'net/http'
require 'uri'

module Integrations
  module MonitorSe
    class MonitorSe
      include Integrations::MonitorSe::Endpoints::Parts
      include Integrations::MonitorSe::Endpoints::StockBalanceChanges
      include Integrations::MonitorSe::Endpoints::PhysicalInventoryLists
      include Integrations::MonitorSe::Endpoints::InventoryCommands
      include Integrations::MonitorSe::Endpoints::QuantityChanges
      
      attr_reader :session_id, :base_url, :language_code, :company_number

      def initialize(language_code: 'lt', company_number: '001.1')
        @base_url = Rails.application.secrets[:MONITOR_SE_URL]
        @username = Rails.application.secrets[:MONITOR_SE_USER_NAME]
        @password = Rails.application.secrets[:MONITOR_SE_PASSWORD]
        @language_code = language_code
        @company_number = company_number
        @session_id = nil
      end

      def authenticate
        uri = URI(login_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        
        request = Net::HTTP::Post.new(uri)
        headers.each { |k, v| request[k] = v }
        request.body = login_body.to_json

        response = http.request(request)
        handle_authentication_response(response)
      end

      def authenticated?
        @session_id.present?
      end

      def headers(include_session: false)
        base_headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Cache-Control' => 'no-cache'
        }

        if include_session && @session_id.present?
          base_headers['X-Monitor-SessionId'] = @session_id
        end

        base_headers
      end

      private

      def api_base_url
        "#{@base_url}/#{@language_code}/#{@company_number}/api/v1"
      end

      def login_url
        "#{@base_url}/#{@language_code}/#{@company_number}/login"
      end

      def login_body
        {
          'Username' => @username,
          'Password' => @password,
          'ForceRelogin' => false
        }
      end

      def handle_authentication_response(response)
        if response.code == 200
          @session_id = response.headers['X-Monitor-SessionId']
          
          body = JSON.parse(response.body)
          mfa_token = body['MfaToken']
          
          if mfa_token.present?
            raise 'Multi-factor authentication required but not implemented'
          end
          
          @session_id
        elsif response.code == 403
          error_message = JSON.parse(response.body)
          raise "Authentication failed: #{error_message}"
        else
          raise "Unexpected response: #{response.code} - #{response.body}"
        end
      end

      def handle_api_response(response)
        case response.code.to_i
        when 200
          JSON.parse(response.body)
        when 401
          raise 'Unauthorized: Session expired or invalid'
        when 403
          raise 'Forbidden: Insufficient permissions'
        when 404
          raise 'Not found: Resource does not exist'
        else
          raise "API request failed: #{response.code} - #{response.body}"
        end
      end

      def ensure_authenticated
        authenticate unless authenticated?
      end

      def make_request(method, path, params = {})
        uri = URI("#{@base_url}/#{@language_code}/#{@company_number}/api/v1" + path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        case method.downcase.to_sym
        when :get
          request = Net::HTTP::Get.new(uri)
          uri.query = URI.encode_www_form(params) if params.any?
        when :post
          request = Net::HTTP::Post.new(uri)
          request.body = params.to_json
        end

        headers(include_session: true).each { |k, v| request[k] = v }
        http.request(request)
      end

      def build_query_params(filters, expand)
        params = {}
        
        if filters.any?
          filter_conditions = filters.map do |key, value|
            value_str = value.is_a?(String) ? "'#{value}'" : value
            "#{key} eq #{value_str}"
          end
          params['$filter'] = filter_conditions.join(' and ')
        end
        
        params['$expand'] = expand.join(',') if expand.any?
        
        params
      end
    end
  end
end