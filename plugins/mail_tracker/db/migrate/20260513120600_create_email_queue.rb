class CreateEmailQueue < ActiveRecord::Migration[6.1]
  def change
    create_table :email_queues do |t|
      t.string :mailer_class, null: false
      t.string :mailer_method, null: false
      t.string :delivery_method, null: false
      t.text :serialized_args, null: false
      t.text :serialized_mail
      t.string :recipient_email
      t.string :subject
      t.integer :retry_count, default: 0, null: false
      t.datetime :last_attempted_at
      t.datetime :delivered_at
      t.datetime :failed_at
      t.timestamps
    end

    add_index :email_queues, :delivered_at
    add_index :email_queues, :created_at
    add_index :email_queues, [:delivered_at, :created_at]
    add_index :email_queues, :last_attempted_at
  end
end
