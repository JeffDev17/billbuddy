class AddIndexToAppointmentsReminderSentAt < ActiveRecord::Migration[7.2]
  def change
    add_index :appointments, :reminder_sent_at
  end
end
