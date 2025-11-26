module Integrations
  module MonitorSe
    module Endpoints
      module QuantityChanges
        def get_quantity_changes(filters: {}, expand: [])
          ensure_authenticated
          
          query_params = build_query_params(filters, expand)
          url = "#{api_base_url}/Inventory/QuantityChanges#{query_params}"
          
          response = self.class.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def get_quantity_change(quantity_change_id, expand: [])
          ensure_authenticated
          
          query_params = expand.any? ? "?$expand=#{expand.join(',')}" : ''
          url = "#{api_base_url}/Inventory/QuantityChanges(#{quantity_change_id})#{query_params}"
          
          response = self.class.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def search_quantity_changes(part_id: nil, warehouse_id: nil, status: nil, actual_delivery_date: nil, expand: [])
          filters = {}
          filters[:PartId] = part_id if part_id.present?
          filters[:WarehouseId] = warehouse_id if warehouse_id.present?
          filters[:Status] = status if status.present?
          filters[:ActualDeliveryDate] = actual_delivery_date if actual_delivery_date.present?
          
          get_quantity_changes(filters: filters, expand: expand)
        end
      end
    end
  end
end
