class AddReminderSentAtToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :reminder_sent_at, :datetime
  end
end
