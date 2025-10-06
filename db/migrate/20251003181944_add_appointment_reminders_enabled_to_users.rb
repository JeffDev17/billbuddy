class AddAppointmentRemindersEnabledToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :appointment_reminders_enabled, :boolean, default: false, null: false
  end
end
