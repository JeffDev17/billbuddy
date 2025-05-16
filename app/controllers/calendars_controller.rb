class CalendarsController < ApplicationController
  def index
    if session[:authorization].blank?
      @todays_events = []
      return
    end

    begin
      client = Signet::OAuth2::Client.new(client_options)
      client.update!(session[:authorization])

      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = client

      # Configurar o intervalo de tempo para hoje
      time_min = Time.zone.now.beginning_of_day.iso8601
      time_max = Time.zone.now.end_of_day.iso8601

      # Buscar eventos de hoje de todos os calendários
      @todays_events = []
      calendar_list = service.list_calendar_lists
      calendar_list.items.each do |calendar|
        events = service.list_events(
          calendar.id,
          time_min: time_min,
          time_max: time_max,
          single_events: true,
          order_by: 'startTime'
        )
        @todays_events.concat(events.items) if events.items.any?
      end

      @todays_events.sort_by! { |event| event.start.date_time || event.start.date }
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
      session[:authorization] = nil
      @todays_events = []
      redirect_to redirect_calendars_path
    rescue => e
      Rails.logger.error "Google Calendar Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @todays_events = []
      flash[:alert] = "Erro ao acessar o Google Calendar. Por favor, tente novamente."
    end
  end

  def redirect
    client = Signet::OAuth2::Client.new(client_options)
    
    # Add debugging to verify client options
    Rails.logger.debug "Client Options: #{client_options.inspect}"
    Rails.logger.debug "Client ID: #{ENV['GOOGLE_CLIENT_ID'].inspect}"
    Rails.logger.debug "Client Secret: #{ENV['GOOGLE_CLIENT_SECRET'].inspect}"
    
    respond_to do |format|
      format.json { render json: { url: client.authorization_uri.to_s } }
      format.html { redirect_to client.authorization_uri.to_s, allow_other_host: true }
    end
  rescue => e
    Rails.logger.error "Google Calendar Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render plain: "Error: #{e.message}", status: :internal_server_error
  end

  def callback
    client = Signet::OAuth2::Client.new(client_options)
    client.code = params[:code]
    response = client.fetch_access_token!
    session[:authorization] = response

    redirect_to calendars_path
  end

  def events
    client = Signet::OAuth2::Client.new(client_options)
    client.update!(session[:authorization])

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client

    @event_list = service.list_events(params[:calendar_id])
  rescue Google::Apis::AuthorizationError
    response = client.refresh!
    session[:authorization] = session[:authorization].merge(response)
    retry
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