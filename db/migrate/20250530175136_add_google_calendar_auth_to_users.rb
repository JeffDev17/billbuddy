class AddGoogleCalendarAuthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :google_calendar_token, :text
    add_column :users, :google_calendar_refresh_token, :string
    add_column :users, :google_calendar_expires_at, :datetime
  end
end
