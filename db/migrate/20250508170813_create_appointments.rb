class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :customer, null: false, foreign_key: true
      t.datetime :scheduled_at
      t.float :duration
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
