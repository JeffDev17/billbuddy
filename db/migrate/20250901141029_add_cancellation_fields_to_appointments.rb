class AddCancellationFieldsToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :cancellation_type, :string
    add_column :appointments, :cancellation_reason, :text
    add_column :appointments, :cancelled_at, :datetime
    add_column :appointments, :reschedule_deadline, :datetime
  end
end
