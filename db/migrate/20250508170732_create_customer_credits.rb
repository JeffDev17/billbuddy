class CreateCustomerCredits < ActiveRecord::Migration[7.2]
  def change
    create_table :customer_credits do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :service_package, null: false, foreign_key: true
      t.float :remaining_hours
      t.datetime :purchase_date

      t.timestamps
    end
  end
end
