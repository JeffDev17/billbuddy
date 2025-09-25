class AddGoogleEventIdToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :google_event_id, :string unless column_exists?(:appointments, :google_event_id)
  end
end
