class AddCustomHourlyRateToCustomers < ActiveRecord::Migration[7.2]
  def change
    add_column :customers, :custom_hourly_rate, :decimal
  end
end
