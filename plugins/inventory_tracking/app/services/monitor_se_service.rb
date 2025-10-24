class MonitorSeService
  def initialize
    @client = Integrations::MonitorSe.new
  end

  def sync_parts
    # Fetch all parts from Monitor.se
    parts_data = @client.get_parts(
      filters: { ManageStockBalance: true },
      expand: ['ProductGroup']
    )
    
    parts_data['value'].each do |part_data|
      sync_part(part_data)
    end
  end

  def sync_part_balances(part_id, warehouse_id)
    # Get balance info from Monitor.se
    balance_info = @client.get_part_balance_info(
      part_id: part_id,
      warehouse_id: warehouse_id
    )
    
    # Update local database
    update_part_balance(balance_info)
  end

  def sync_quantity_changes(from_date: 1.day.ago)
    # Fetch recent quantity changes
    changes = @client.get_quantity_changes(
      filters: { ActualDeliveryDate: "ge #{from_date.iso8601}" },
      expand: ['Part', 'Warehouse']
    )
    
    changes['value'].each do |change_data|
      log_quantity_change(change_data)
    end
  end

  private

  def sync_part(part_data)
    MonitorSePart.find_or_initialize_by(monitor_part_id: part_data['Id']).tap do |part|
      part.part_number = part_data['PartNumber']
      part.description = part_data['Description']
      part.part_type = part_data['Type']
      part.status = part_data['Status']
      part.manage_stock_balance = part_data['ManageStockBalance']
      part.metadata = part_data
      part.last_synced_at = Time.current
      part.save!
    end
  end

  def update_part_balance(balance_info)
    # Implementation depends on balance_info structure
  end

  def log_quantity_change(change_data)
    # Implementation for logging changes
  end
end