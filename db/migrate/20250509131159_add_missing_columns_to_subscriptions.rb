class AddMissingColumnsToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :end_date, :date
    add_column :subscriptions, :billing_day, :integer
    add_column :subscriptions, :notes, :text
  end
end
