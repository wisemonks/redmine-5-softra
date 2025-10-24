module Integrations
  module MonitorSe
    module Endpoints
      module StockBalanceChanges
        def get_stock_balance_changes(filters: {}, expand: [])
          ensure_authenticated
          
          query_params = build_query_params(filters, expand)
          url = "#{api_base_url}/Inventory/StockBalanceChanges#{query_params}"
          
          response = HTTParty.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def get_stock_balance_change(stock_balance_change_id, expand: [])
          ensure_authenticated
          
          query_params = expand.any? ? "?$expand=#{expand.join(',')}" : ''
          url = "#{api_base_url}/Inventory/StockBalanceChanges(#{stock_balance_change_id})#{query_params}"
          
          response = HTTParty.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def search_stock_balance_changes(part_location_id: nil, product_record_id: nil, quantity_change_id: nil, expand: [])
          filters = {}
          filters[:PartLocationId] = part_location_id if part_location_id.present?
          filters[:ProductRecordId] = product_record_id if product_record_id.present?
          filters[:QuantityChangeId] = quantity_change_id if quantity_change_id.present?
          
          get_stock_balance_changes(filters: filters, expand: expand)
        end
      end
    end
  end
end