module Integrations
  module MonitorSe
    module Endpoints
      module InventoryCommands
        def stock_count(part_id:, balance:, warehouse_id: nil, location_name: nil, part_location_id: nil, delivery_date: nil, serial_number: nil, batch_number: nil, best_before_date: nil, comment: nil)
          ensure_authenticated
          
          validate_stock_count_params(warehouse_id, location_name, part_location_id)
          
          body = build_stock_count_body(
            part_id: part_id,
            balance: balance,
            warehouse_id: warehouse_id,
            location_name: location_name,
            part_location_id: part_location_id,
            delivery_date: delivery_date,
            serial_number: serial_number,
            batch_number: batch_number,
            best_before_date: best_before_date,
            comment: comment
          )
          
          url = "#{api_base_url}/Inventory/Parts/StockCount"
          response = self.class.post(
            url,
            headers: headers(include_session: true),
            body: body.to_json
          )
          
          handle_api_response(response)
        end

        def get_part_balance_info(part_id:, warehouse_id:, balance_date: nil, actual_orders_transaction_type: nil, preliminary_transaction_type: nil, forecasts_transaction_type: nil, suggestions_transaction_type: nil)
          ensure_authenticated
          
          body = build_part_balance_info_body(
            part_id: part_id,
            warehouse_id: warehouse_id,
            balance_date: balance_date,
            actual_orders_transaction_type: actual_orders_transaction_type,
            preliminary_transaction_type: preliminary_transaction_type,
            forecasts_transaction_type: forecasts_transaction_type,
            suggestions_transaction_type: suggestions_transaction_type
          )
          
          url = "#{api_base_url}/Inventory/Parts/GetPartBalanceInfo"
          response = self.class.post(
            url,
            headers: headers(include_session: true),
            body: body.to_json
          )
          
          handle_api_response(response)
        end

        private

        def validate_stock_count_params(warehouse_id, location_name, part_location_id)
          if part_location_id.nil?
            if warehouse_id.nil? || location_name.nil?
              raise ArgumentError, 'Either part_location_id must be provided, or both warehouse_id and location_name must be provided'
            end
          end
        end

        def build_stock_count_body(part_id:, balance:, warehouse_id:, location_name:, part_location_id:, delivery_date:, serial_number:, batch_number:, best_before_date:, comment:)
          body = {
            'PartId' => part_id,
            'Balance' => balance
          }
          
          body['WarehouseId'] = warehouse_id if warehouse_id.present?
          body['Name'] = location_name if location_name.present?
          body['PartLocationId'] = part_location_id if part_location_id.present?
          body['DeliveryDate'] = delivery_date if delivery_date.present?
          body['SerialNumber'] = serial_number if serial_number.present?
          body['BatchNumber'] = batch_number if batch_number.present?
          body['BestBeforeDate'] = best_before_date if best_before_date.present?
          body['Comment'] = comment if comment.present?
          
          body
        end

        def build_part_balance_info_body(part_id:, warehouse_id:, balance_date:, actual_orders_transaction_type:, preliminary_transaction_type:, forecasts_transaction_type:, suggestions_transaction_type:)
          body = {
            'PartId' => part_id,
            'WarehouseId' => warehouse_id
          }
          
          body['BalanceDate'] = balance_date if balance_date.present?
          body['ActualOrdersTransactionType'] = actual_orders_transaction_type if actual_orders_transaction_type.present?
          body['PreliminaryTransactionType'] = preliminary_transaction_type if preliminary_transaction_type.present?
          body['ForecastsTransactionType'] = forecasts_transaction_type if forecasts_transaction_type.present?
          body['SuggestionsTransactionType'] = suggestions_transaction_type if suggestions_transaction_type.present?
          
          body
        end
      end
    end
  end
end
