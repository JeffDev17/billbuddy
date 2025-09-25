class SimplePricingMigration < ActiveRecord::Migration[7.0]
  def up
    # Add appointment rate storage for historical preservation
    add_column :appointments, :hourly_rate, :decimal, precision: 8, scale: 2 unless column_exists?(:appointments, :hourly_rate)
    add_column :appointments, :rate_source, :string unless column_exists?(:appointments, :rate_source)
    add_index :appointments, :rate_source unless index_exists?(:appointments, :rate_source)

    # Rename existing customer pricing fields to be clearer
    if column_exists?(:customers, :package_value) && !column_exists?(:customers, :monthly_amount)
      rename_column :customers, :package_value, :monthly_amount
    end

    if column_exists?(:customers, :package_hours) && !column_exists?(:customers, :monthly_hours)
      rename_column :customers, :package_hours, :monthly_hours
    end

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
