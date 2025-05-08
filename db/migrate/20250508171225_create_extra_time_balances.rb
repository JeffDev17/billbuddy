class CreateExtraTimeBalances < ActiveRecord::Migration[7.2]
  def change
    create_table :extra_time_balances do |t|
      t.references :customer, null: false, foreign_key: true
      t.float :hours
      t.date :expiry_date

      t.timestamps
    end
  end
end
