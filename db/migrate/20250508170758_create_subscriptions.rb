class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :customer, null: false, foreign_key: true
      t.decimal :amount
      t.date :start_date
      t.string :status

      t.timestamps
    end
  end
end
