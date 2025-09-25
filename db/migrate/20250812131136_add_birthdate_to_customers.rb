class AddBirthdateToCustomers < ActiveRecord::Migration[7.2]
  def change
    add_column :customers, :birthdate, :date
  end
end
