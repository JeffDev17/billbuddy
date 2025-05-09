class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :payment_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :payment_date, null: false
      t.text :notes

      t.timestamps
    end
  end
end
