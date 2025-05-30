class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :customers, dependent: :destroy

  # Google Calendar integration
  def google_calendar_authorized?
    google_calendar_token.present? &&
    (google_calendar_expires_at.nil? || google_calendar_expires_at > Time.current)
  end

  def session_authorization
    return nil unless google_calendar_authorized?

    {
      "access_token" => google_calendar_token,
      "refresh_token" => google_calendar_refresh_token,
      "expires_at" => google_calendar_expires_at&.to_i
    }
  end

  def update_google_calendar_auth(auth_hash)
    update!(
      google_calendar_token: auth_hash["access_token"],
      google_calendar_refresh_token: auth_hash["refresh_token"] || google_calendar_refresh_token,
      google_calendar_expires_at: auth_hash["expires_at"] ? Time.at(auth_hash["expires_at"]) : nil
    )
  end

  def clear_google_calendar_auth
    update!(
      google_calendar_token: nil,
      google_calendar_refresh_token: nil,
      google_calendar_expires_at: nil
    )
  end
end
