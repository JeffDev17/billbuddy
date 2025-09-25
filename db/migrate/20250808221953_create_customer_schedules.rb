class CreateCustomerSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :customer_schedules do |t|
      t.references :customer, null: false, foreign_key: true
      t.integer :day_of_week
      t.time :start_time
      t.decimal :duration
      t.boolean :enabled

      t.timestamps
    end
  end
end
