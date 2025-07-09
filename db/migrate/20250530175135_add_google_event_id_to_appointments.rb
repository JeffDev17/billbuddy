class AddGoogleEventIdToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :google_event_id, :string
    add_column :appointments, :is_recurring_event, :boolean, default: false
  end
end
