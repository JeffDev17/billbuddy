class CreateCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :status
      t.string :plan_type
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
