class GoogleCalendarService
  def initialize(user)
    @user = user
  end

  def setup_calendar_service
    authorization = @user.session_authorization
    return nil unless authorization

    begin
      client = Signet::OAuth2::Client.new(client_options)
      client.update!(authorization)

      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = client
      service
    rescue => e
      Rails.logger.error "Failed to setup Google Calendar service: #{e.message}"
      nil
    end
  end

  def create_oauth_client
    Signet::OAuth2::Client.new(client_options)
  end

  def authorization_uri
    create_oauth_client.authorization_uri.to_s
  end

  def process_oauth_callback(code)
    client = create_oauth_client
    client.code = code
    client.fetch_access_token!
  end

  private

  def client_options
    base_url = Rails.env.production? ? "https://billbuddy.com.br" : "http://localhost.billbuddy.com.br:3000"
    {
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      authorization_uri: "https://accounts.google.com/o/oauth2/auth",
      token_credential_uri: "https://oauth2.googleapis.com/token",
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      redirect_uri: "#{base_url}/google/oauth2/callback",
      additional_parameters: { access_type: "offline", prompt: "consent" }
    }
  end
end
