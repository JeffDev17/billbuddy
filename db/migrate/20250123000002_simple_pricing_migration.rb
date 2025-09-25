class SimplePricingMigration < ActiveRecord::Migration[7.0]
  def up
    # Add appointment rate storage for historical preservation
    add_column :appointments, :hourly_rate, :decimal, precision: 8, scale: 2
    add_column :appointments, :rate_source, :string
    add_index :appointments, :rate_source

    # Rename existing customer pricing fields to be clearer
    rename_column :customers, :package_value, :monthly_amount
    rename_column :customers, :package_hours, :monthly_hours

    # We'll backfill the data in a separate step after everything is working
  end

  def down
    # Remove appointment rate fields
    remove_column :appointments, :hourly_rate
    remove_column :appointments, :rate_source

    # Revert customer pricing field names
    rename_column :customers, :monthly_amount, :package_value
    rename_column :customers, :monthly_hours, :package_hours
  end
end
