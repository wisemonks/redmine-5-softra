module Integrations
  module MonitorSe
    module Endpoints
      module PhysicalInventoryLists
        def get_physical_inventory_lists(filters: {}, expand: [])
          ensure_authenticated
          
          query_params = build_query_params(filters, expand)
          url = "#{api_base_url}/Inventory/PhysicalInventoryLists#{query_params}"
          
          response = self.class.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def get_physical_inventory_list(list_id, expand: [])
          ensure_authenticated
          
          query_params = expand.any? ? "?$expand=#{expand.join(',')}" : ''
          url = "#{api_base_url}/Inventory/PhysicalInventoryLists(#{list_id})#{query_params}"
          
          response = self.class.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def search_physical_inventory_lists(warehouse_id: nil, number: nil, state: nil, inventory_status: nil, expand: [])
          filters = {}
          filters[:WarehouseId] = warehouse_id if warehouse_id.present?
          filters[:Number] = number if number.present?
          filters[:State] = state if state.present?
          filters[:InventoryStatus] = inventory_status if inventory_status.present?
          
          get_physical_inventory_lists(filters: filters, expand: expand)
        end
      end
    end
  end
end