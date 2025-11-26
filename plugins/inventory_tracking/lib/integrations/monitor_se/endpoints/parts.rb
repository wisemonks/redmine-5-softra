module Integrations
  module MonitorSe
    module Endpoints
      module Parts
        def get_parts(filters: {}, expand: [])
          ensure_authenticated
          
          query_params = build_query_params(filters, expand)
          url = "#{api_base_url}/Inventory/Parts#{query_params}"
          
          response = self.class.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def get_part(part_id, expand: [])
          ensure_authenticated
          
          query_params = expand.any? ? "?$expand=#{expand.join(',')}" : ''
          url = "#{api_base_url}/Inventory/Parts(#{part_id})#{query_params}"
          
          response = self.class.get(url, headers: headers(include_session: true))
          handle_api_response(response)
        end

        def search_parts(part_number: nil, description: nil, product_group_id: nil, status: nil, expand: [])
          filters = {}
          filters[:PartNumber] = part_number if part_number.present?
          filters[:Description] = description if description.present?
          filters[:ProductGroupId] = product_group_id if product_group_id.present?
          filters[:Status] = status if status.present?
          
          get_parts(filters: filters, expand: expand)
        end
      end
    end
  end
end