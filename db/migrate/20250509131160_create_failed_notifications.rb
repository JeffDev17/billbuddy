class CreateFailedNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :failed_notifications do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :notification_type, null: false
      t.text :error_message, null: false
      t.timestamps
    end

    add_index :failed_notifications, [:customer_id, :notification_type]
  end
end 