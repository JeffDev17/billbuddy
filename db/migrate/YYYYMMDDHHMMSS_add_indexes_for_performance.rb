class AddIndexesForPerformance < ActiveRecord::Migration[7.2]
  def change
    add_index :customer_credits, :remaining_hours
    add_index :customer_credits, :purchase_date
    add_index :appointments, :scheduled_at
    add_index :appointments, :status
    add_index :subscriptions, :status
    add_index :subscriptions, :start_date
    add_index :customers, :status
    add_index :customers, :plan_type
  end
end 