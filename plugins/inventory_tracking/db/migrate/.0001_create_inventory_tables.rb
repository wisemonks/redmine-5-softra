class CreateInventoryTables < ActiveRecord::Migration
  create_table :monitor_se_parts do |t|
    t.bigint :monitor_part_id, null: false, index: true, unique: true
    t.string :part_number, limit: 20
    t.string :description
    t.string :extra_description
    t.integer :part_type # 0=Purchased, 1=Manufactured, 2=Fictitious, 5=Service, 6=Subcontract
    t.integer :status # 1=Quote, 2=Prototype, 3=New, 4=Normal, etc.
    t.bigint :product_group_id
    t.decimal :standard_price, precision: 15, scale: 2
    t.decimal :weight_per_unit, precision: 15, scale: 4
    t.boolean :manage_stock_balance, default: false
    t.jsonb :metadata # Store additional fields as JSON
    t.datetime :last_synced_at
    t.timestamps
  end

  create_table :monitor_se_part_balances do |t|
    t.references :monitor_se_part, foreign_key: true, null: false
    t.bigint :warehouse_id, null: false
    t.string :warehouse_name
    t.decimal :available_balance, precision: 15, scale: 4, default: 0
    t.decimal :physical_balance, precision: 15, scale: 4, default: 0
    t.decimal :reserved_balance, precision: 15, scale: 4, default: 0
    t.decimal :incoming_balance, precision: 15, scale: 4, default: 0
    t.datetime :balance_date
    t.datetime :last_synced_at
    t.timestamps
    
    t.index [:monitor_se_part_id, :warehouse_id], unique: true
  end

  create_table :monitor_se_quantity_changes do |t|
    t.bigint :monitor_quantity_change_id, null: false, index: true, unique: true
    t.references :monitor_se_part, foreign_key: true
    t.bigint :warehouse_id
    t.decimal :balance_change, precision: 15, scale: 4
    t.decimal :available_balance, precision: 15, scale: 4
    t.integer :status # 1=Cleared, 2=Picking, 3=OutgoingDelivery, etc.
    t.datetime :actual_delivery_date
    t.datetime :synced_at
    t.timestamps
  end

  create_table :monitor_se_sync_logs do |t|
    t.string :sync_type # 'parts', 'balances', 'quantity_changes'
    t.datetime :started_at
    t.datetime :completed_at
    t.integer :records_processed, default: 0
    t.integer :records_failed, default: 0
    t.string :status # 'running', 'completed', 'failed'
    t.text :error_message
    t.jsonb :sync_metadata
    t.timestamps
  end
end