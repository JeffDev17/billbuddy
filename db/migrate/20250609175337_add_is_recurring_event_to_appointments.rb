class AddIsRecurringEventToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :is_recurring_event, :boolean
  end
end
