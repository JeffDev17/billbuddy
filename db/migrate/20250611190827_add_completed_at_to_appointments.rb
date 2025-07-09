class AddCompletedAtToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :completed_at, :datetime
  end
end
