require 'httparty'
require 'json'

module Integrations
  class Finvalda
    include HTTParty
    base_uri 'http://172.16.22.3:87/FvsServicePure.svc'
    default_timeout 30

    def initialize
      @username = ENV['finvalda_user_name']
      @password = ENV['finvalda_user_pwd']
      @conn_string = ENV['finvalda_production_company_id']
    end

    def headers
      {
        'Content-Type' => 'application/json; charset=utf-8',
        'UserName' => @username,
        'Password' => @password,
        'ConnString' => @conn_string,
        'RemoveEmptyStringTags' => 'false',
        'RemoveZeroNumberTags' => 'false',
        'RemoveNewLines' => 'false',
        'Language' => '0'
      }
    end

    # GetDescriptions method — main JSON endpoint
    def get_descriptions(type:, page: 0, limit: 0, filters: {}, columns: [])
      request_body = {
        readParams: {
          type: type,
          page: page,
          limit: limit
        }.merge(filters.empty? ? {} : filters)
      }
      request_body[:readParams][:columns] = columns unless columns.empty?

      response = self.class.post(
        '/GetDescriptions',
        headers: headers,
        body: request_body.to_json
      )

      handle_response(response)
    rescue => e
      { success: false, error: e.message }
    end

    # ✅ Example: get current stock
    def get_current_stock(warehouse: nil, warehouse_group: 'VISI', type: nil, page: 0, limit: 0)
      filters = {
        'Products' => {
          'Warehouse' => warehouse || '',
          'WarehouseGroup' => warehouse_group,
          'Type' => type || ''
        }
      }

      get_descriptions(
        type: 'CurrentStock',
        page: page,
        limit: limit,
        filters: filters,
        columns: [
          'warehouse', 'warehouse_title', 'code', 'title',
          'quantity', 'quantity_with_reserved',
          'measure_unit', 'primary_cost'
        ]
      )
    end

    private

    def handle_response(response)
      if response.success?
        begin
          parsed = JSON.parse(response.body)
          { success: true, data: parsed }
        rescue JSON::ParserError
          { success: true, raw_response: response.body }
        end
      else
        {
          success: false,
          status: response.code,
          error: "Request failed (#{response.code})",
          body: response.body
        }
      end
    end
  end
end

# Quick test
finvalda = Integrations::Finvalda.new
response = finvalda.get_current_stock
puts response
