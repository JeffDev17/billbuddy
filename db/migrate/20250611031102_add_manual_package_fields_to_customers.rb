class AddManualPackageFieldsToCustomers < ActiveRecord::Migration[7.2]
  def change
    add_column :customers, :package_value, :decimal
    add_column :customers, :package_hours, :decimal
  end
end
