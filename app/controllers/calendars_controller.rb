class CalendarsController < ApplicationController
  before_action :set_google_client, except: [:redirect]
  before_action :set_calendar_service, except: [:redirect]
  
  def index
    if session[:authorization].blank?
      @events = []
      return
    end

    begin
      Time.zone = 'America/Sao_Paulo'
      
      @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
      time_min = @selected_date.beginning_of_day.iso8601
      time_max = @selected_date.end_of_day.iso8601

      @events = []
      calendar_list = @service.list_calendar_lists
      calendar_list.items.each do |calendar|
        events = @service.list_events(
          calendar.id,
          time_min: time_min,
          time_max: time_max,
          single_events: true,
          order_by: 'startTime'
        )
        @events.concat(events.items) if events.items.any?
      end

      @events.sort_by! { |event| event.start.date_time || event.start.date }

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("events_list", partial: "events_list"),
            turbo_stream.replace("date_navigation", partial: "date_navigation")
          ]
        end
      end
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
      handle_authorization_error
    rescue => e
      handle_calendar_error(e)
    end
  end

  def redirect
    client = Signet::OAuth2::Client.new(client_options)
    
    respond_to do |format|
      format.json { render json: { url: client.authorization_uri.to_s } }
      format.html { redirect_to client.authorization_uri.to_s, allow_other_host: true }
    end
  rescue => e
    handle_calendar_error(e)
  end

  def callback
    client = Signet::OAuth2::Client.new(client_options)
    client.code = params[:code]
    response = client.fetch_access_token!
    session[:authorization] = response

    redirect_to calendars_path
  end

  def events
    @event_list = @service.list_events(params[:calendar_id])
  rescue Google::Apis::AuthorizationError
    response = @client.refresh!
    session[:authorization] = session[:authorization].merge(response)
    retry
  end

  def create_event
    begin
      event = build_event
      result = @service.insert_event(params[:calendar_id] || 'primary', event)

      respond_to do |format|
        format.json { render json: result }
        format.html { 
          notice_msg = event.recurrence ? 'Evento recorrente criado com sucesso!' : 'Evento criado com sucesso!'
          redirect_to calendars_path, notice: notice_msg 
        }
      end
    rescue Google::Apis::ClientError => e
      handle_client_error(e)
    rescue Google::Apis::AuthorizationError
      handle_authorization_error
    rescue => e
      handle_calendar_error(e)
    end
  end

  def update_event
    begin
      calendar_id = params[:calendar_id] || 'primary'
      event = @service.get_event(calendar_id, params[:event_id])
      
      event_id = handle_recurring_event_update(event, calendar_id)
      update_event_attributes(event)
      
      result = @service.update_event(calendar_id, event_id, event)

      respond_to do |format|
        format.json { render json: result }
        format.html { 
          message = get_update_success_message(event.recurring_event_id.present?, params[:update_type])
          redirect_to calendars_path, notice: message 
        }
      end
    rescue Google::Apis::ClientError => e
      handle_client_error(e)
    rescue Google::Apis::AuthorizationError
      handle_authorization_error
    rescue => e
      handle_calendar_error(e)
    end
  end

  def delete_event
    begin
      calendar_id = params[:calendar_id] || 'primary'
      event = @service.get_event(calendar_id, params[:event_id])
      
      delete_options = {}
      
      if event.recurring_event_id.present? || event.recurrence.present?
        delete_type = params[:delete_type] || 'single'
        
        if delete_type == 'all'
          event_id = event.recurring_event_id.presence || params[:event_id]
        else
          event_id = params[:event_id]
          delete_options[:instance_id] = event.id if event.recurring_event_id.present?
        end
      else
        event_id = params[:event_id]
      end

      @service.delete_event(calendar_id, event_id, **delete_options)

      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to calendars_path, notice: 'Evento excluído com sucesso!' }
      end
    rescue Google::Apis::AuthorizationError
      handle_authorization_error
    rescue => e
      handle_calendar_error(e)
    end
  end

  private

  def set_google_client
    @client = Signet::OAuth2::Client.new(client_options)
    @client.update!(session[:authorization]) if session[:authorization].present?
  end

  def set_calendar_service
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = @client
  end

  def client_options
    base_url = Rails.env.production? ? "https://billbuddy.com.br" : "http://localhost.billbuddy.com.br:3000"

    {
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      redirect_uri: "#{base_url}/google/oauth2/callback",
      additional_parameters: {
        access_type: 'offline',
        prompt: 'consent'
      }
    }
  end

  def build_event
    attendees_array = params[:attendees].present? ? 
      params[:attendees].split(',').map(&:strip).map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) } : 
      []

    start_time = parse_datetime(params[:start_time])
    end_time = parse_datetime(params[:end_time])

    event = Google::Apis::CalendarV3::Event.new(
      summary: params[:summary].presence || 'Sem título',
      location: params[:location],
      description: params[:description],
      start: create_event_datetime(start_time),
      end: create_event_datetime(end_time),
      attendees: attendees_array,
      reminders: { use_default: true }
    )

    add_recurrence_rule(event) if params[:recurring_days].present?
    event
  end

  def parse_datetime(datetime_str)
    ActiveSupport::TimeZone['America/Sao_Paulo'].parse(datetime_str)
  end

  def create_event_datetime(time)
    Google::Apis::CalendarV3::EventDateTime.new(
      date_time: time.iso8601,
      time_zone: 'America/Sao_Paulo'
    )
  end

  def add_recurrence_rule(event)
    days_of_week = params[:recurring_days].map { |day| %w(SU MO TU WE TH FR SA)[day.to_i] }.join(',')
    rrule = "RRULE:FREQ=WEEKLY;BYDAY=#{days_of_week}"
    
    if params[:recurring_until].present? && params[:no_end_date] != "true"
      until_date = Date.parse(params[:recurring_until]).strftime('%Y%m%d')
      rrule += ";UNTIL=#{until_date}T235959Z"
    end
    
    event.recurrence = [rrule]
  end

  def handle_recurring_event_update(event, calendar_id)
    return event.id unless event.recurring_event_id.present?

    update_type = params[:update_type] || 'single'
    if update_type == 'all'
      event_id = event.recurring_event_id
      event = @service.get_event(calendar_id, event_id)
    else
      event_id = event.id
    end
    event_id
  end

  def update_event_attributes(event)
    event.summary = params[:summary].presence || event.summary
    event.location = params[:location].presence || event.location
    event.description = params[:description].presence || event.description

    if params[:start_time].present?
      event.start = create_event_datetime(parse_datetime(params[:start_time]))
    end

    if params[:end_time].present?
      event.end = create_event_datetime(parse_datetime(params[:end_time]))
    end

    if params[:attendees].present?
      event.attendees = params[:attendees].split(',').map(&:strip).map { |email| 
        Google::Apis::CalendarV3::EventAttendee.new(email: email)
      }
    end

    add_recurrence_rule(event) if params[:recurring_days].present?
  end

  def get_update_success_message(is_recurring, update_type)
    if is_recurring
      update_type == 'single' ? 'Instância do evento atualizada com sucesso!' : 'Série de eventos atualizada com sucesso!'
    else
      'Evento atualizado com sucesso!'
    end
  end

  def handle_authorization_error
    session[:authorization] = nil
    @events = [] if action_name == 'index'
    respond_to do |format|
      format.json { render json: { error: 'Autorização expirada' }, status: :unauthorized }
      format.html { redirect_to redirect_calendars_path, alert: 'Autorização expirada. Por favor, faça login novamente.' }
    end
  end

  def handle_client_error(error)
    Rails.logger.error "Google Calendar API Error: #{error.message}"
    Rails.logger.error "Response body: #{error.body}"
    respond_to do |format|
      format.json { render json: { error: error.message }, status: :unprocessable_entity }
      format.html { redirect_to calendars_path, alert: "Erro ao processar evento: #{error.message}" }
    end
  end

  def handle_calendar_error(error)
    Rails.logger.error "Google Calendar Error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    @events = [] if action_name == 'index'
    respond_to do |format|
      format.json { render json: { error: error.message }, status: :unprocessable_entity }
      format.html { redirect_back(fallback_location: calendars_path, alert: "Erro ao processar sua solicitação: #{error.message}") }
    end
  end
end