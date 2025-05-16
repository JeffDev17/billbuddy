class DashboardController < ApplicationController
  def index
    @customers_count = Customer.count
    @active_customers = Customer.where(status: 'active').count
    @upcoming_appointments = Appointment.order(scheduled_at: :asc).limit(5)

    # Buscar eventos do Google Calendar para hoje e amanhã
    if session[:authorization]
      client = Signet::OAuth2::Client.new(client_options)
      client.update!(session[:authorization])
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = client

      today_min = Time.zone.now.beginning_of_day.iso8601
      today_max = Time.zone.now.end_of_day.iso8601
      tomorrow_min = Time.zone.tomorrow.beginning_of_day.iso8601
      tomorrow_max = Time.zone.tomorrow.end_of_day.iso8601

      calendar_list = service.list_calendar_lists
      
      @todays_classes = 0
      @tomorrows_classes = 0

      calendar_list.items.each do |calendar|
        # Eventos de hoje
        today_events = service.list_events(
          calendar.id,
          time_min: today_min,
          time_max: today_max,
          single_events: true
        )
        @todays_classes += today_events.items.count if today_events.items

        # Eventos de amanhã
        tomorrow_events = service.list_events(
          calendar.id,
          time_min: tomorrow_min,
          time_max: tomorrow_max,
          single_events: true
        )
        @tomorrows_classes += tomorrow_events.items.count if tomorrow_events.items
      end
    end
  rescue Google::Apis::AuthorizationError
    @todays_classes = 0
    @tomorrows_classes = 0
  end

  private

  def client_options
    base_url = if Rails.env.production?
      "https://billbuddy.com.br"
    else
      "http://localhost.billbuddy.com.br:3000"
    end

    {
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY,
      redirect_uri: "#{base_url}/google/oauth2/callback",
      additional_parameters: {
        access_type: 'offline',
        prompt: 'consent'
      }
    }
  end
end