require "ostruct"

class CalendarsController < ApplicationController
  before_action :set_google_client, except: [ :redirect ]
  before_action :set_calendar_service, except: [ :redirect ]

  def index
    @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
    @view_mode = params[:view_mode] || "appointments" # 'appointments' or 'calendar_events'

    if @view_mode == "appointments"
      setup_appointments_for_date
    else
      setup_calendar_events_for_date
    end

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("date_navigation", partial: "date_navigation"),
          turbo_stream.update("events_list", partial: "events_list")
        ]
      end
    end
  end

  def redirect
    client = Signet::OAuth2::Client.new(client_options)
    redirect_to client.authorization_uri.to_s, allow_other_host: true
  end

  def callback
    client = Signet::OAuth2::Client.new(client_options)
    client.code = params[:code]
    response = client.fetch_access_token!

    # Store in both session (backward compatibility) and user model (new approach)
    session[:authorization] = response
    current_user.update_google_calendar_auth(response) if current_user

    redirect_to calendars_path
  end

  def create_event
    event = build_event
    @service.insert_event("primary", event)
    message = event.recurrence ? "Evento recorrente criado!" : "Evento criado!"

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = params[:event_date].present? ? Date.parse(params[:event_date]) : Date.today
        @view_mode = params[:view_mode] || "appointments"
        setup_events_for_selected_mode
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  rescue Google::Apis::AuthorizationError
    handle_auth_error
  end

  def update_event
    calendar_id = "primary"
    event = @service.get_event(calendar_id, params[:event_id])

    event_id = handle_recurring_event_update(event, calendar_id)
    update_event_attributes(event)

    @service.update_event(calendar_id, event_id, event)
    message = event.recurring_event_id.present? ? "Série atualizada!" : "Evento atualizado!"

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
        @view_mode = params[:view_mode] || "appointments"
        setup_events_for_selected_mode
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  rescue Google::Apis::AuthorizationError
    handle_auth_error
  end

  def delete_event
    calendar_id = "primary"
    event = @service.get_event(calendar_id, params[:event_id])

    if event.recurring_event_id.present? || event.recurrence.present?
      delete_type = params[:delete_type] || "single"

      if delete_type == "all"
        # Delete the entire series
        event_id = event.recurring_event_id || params[:event_id]
        @service.delete_event(calendar_id, event_id)
      else
        # Delete only this instance
        @service.delete_event(calendar_id, params[:event_id])
      end
    else
      @service.delete_event(calendar_id, params[:event_id])
    end

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: "Evento excluído!" }
      format.turbo_stream do
        @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
        @view_mode = params[:view_mode] || "appointments"
        setup_events_for_selected_mode
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "Evento excluído!" })
        ]
      end
    end
  rescue Google::Apis::AuthorizationError
    handle_auth_error
  end

  # New actions for appointment sync
  def sync_appointment
    appointment = current_user.customers
                             .joins(:appointments)
                             .merge(Appointment.where(id: params[:appointment_id]))
                             .first&.appointments&.find(params[:appointment_id])

    if appointment&.sync_to_calendar
      message = "Compromisso sincronizado com Google Calendar!"
    else
      message = "Erro ao sincronizar compromisso."
    end

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = appointment&.scheduled_at&.to_date || Date.today
        @view_mode = "appointments"
        setup_appointments_for_date
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  end

  def bulk_sync
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.today
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : start_date

    sync_service = GoogleCalendarSyncService.new(current_user)
    synced_count = sync_service.sync_appointments_for_period(start_date, end_date)

    message = "#{synced_count} compromisso(s) sincronizado(s) com Google Calendar!"

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = start_date
        @view_mode = "appointments"
        setup_appointments_for_date
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  end

  def metrics
    @metrics_service = AppointmentMetricsService.new(current_user)
    @monthly_summary = @metrics_service.monthly_summary
    @daily_schedule = @metrics_service.daily_schedule(@selected_date || Date.today)
  end

  private

  def setup_appointments_for_date
    @appointments = Appointment.joins(:customer)
                               .where(customers: { user_id: current_user.id })
                               .scheduled_for_date(@selected_date)
                               .includes(:customer)
                               .order(:scheduled_at)

    # For backward compatibility, convert appointments to event-like objects
    @events = @appointments.map do |appointment|
      appointment_to_event_object(appointment)
    end
  end

  def setup_calendar_events_for_date
    return @events = [] if authorization_unavailable?

    begin
      Time.zone = "America/Sao_Paulo"
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
          order_by: "startTime"
        )
        @events.concat(events.items) if events.items.any?
      end

      @events.sort_by! { |event| event.start.date_time || event.start.date }
    rescue Google::Apis::AuthorizationError
      handle_auth_error
    end
  end

  def setup_events_for_selected_mode
    if @view_mode == "appointments"
      setup_appointments_for_date
    else
      setup_calendar_events_for_date
    end
  end

  # Legacy method for backward compatibility
  def setup_events_for_date
    setup_events_for_selected_mode
  end

  def appointment_to_event_object(appointment)
    # Create an object that mimics Google Calendar event structure
    # for backward compatibility with existing views
    customer = appointment.customer
    start_time = appointment.scheduled_at
    end_time = start_time + appointment.duration.hours

    OpenStruct.new(
      id: "appointment_#{appointment.id}",
      summary: customer.name,
      description: build_appointment_description(appointment),
      start: OpenStruct.new(
        date_time: start_time,
        date: start_time.to_date
      ),
      end: OpenStruct.new(
        date_time: end_time,
        date: end_time.to_date
      ),
      attendees: customer.email.present? ? [ OpenStruct.new(email: customer.email) ] : [],
      # Additional appointment-specific data
      appointment: appointment,
      customer: customer,
      synced_to_calendar: appointment.synced_to_calendar?,
      billbuddy_event: true
    )
  end

  def build_appointment_description(appointment)
    customer = appointment.customer
    description = []

    description << "Cliente: #{customer.name}"
    description << "Email: #{customer.email}" if customer.email.present?
    description << "Telefone: #{customer.phone}" if customer.phone.present?
    description << "Duração: #{appointment.duration} hora(s)"

    if customer.credit?
      description << "Tipo: Crédito (#{customer.total_remaining_hours}h restantes)"
    elsif customer.subscription?
      description << "Tipo: Assinatura"
    end

    description << "Notas: #{appointment.notes}" if appointment.notes.present?

    description.join("\n")
  end

  def authorization_unavailable?
    (session[:authorization].blank? && !current_user&.google_calendar_authorized?)
  end

  def set_google_client
    @client = Signet::OAuth2::Client.new(client_options)

    # Try user's stored authorization first, fall back to session
    authorization = current_user&.session_authorization || session[:authorization]
    @client.update!(authorization) if authorization.present?
  end

  def set_calendar_service
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = @client
  end

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

  def build_event
    attendees = params[:attendees].present? ?
      params[:attendees].split(",").map(&:strip).map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) } :
      []

    start_time = parse_datetime(params[:start_time])
    end_time = parse_datetime(params[:end_time])

    event = Google::Apis::CalendarV3::Event.new(
      summary: params[:summary].presence || "Sem título",
      location: params[:location],
      description: params[:description],
      start: create_event_datetime(start_time),
      end: create_event_datetime(end_time),
      attendees: attendees,
      reminders: { use_default: true }
    )

    add_recurrence_rule(event) if params[:recurring_days].present?
    event
  end

  def parse_datetime(datetime_str)
    ActiveSupport::TimeZone["America/Sao_Paulo"].parse(datetime_str)
  end

  def create_event_datetime(time)
    Google::Apis::CalendarV3::EventDateTime.new(
      date_time: time.iso8601,
      time_zone: "America/Sao_Paulo"
    )
  end

  def add_recurrence_rule(event)
    days = params[:recurring_days].map { |day| %w[SU MO TU WE TH FR SA][day.to_i] }.join(",")
    rrule = "RRULE:FREQ=WEEKLY;BYDAY=#{days}"

    if params[:recurring_until].present? && params[:no_end_date] != "true"
      until_date = Date.parse(params[:recurring_until]).strftime("%Y%m%d")
      rrule += ";UNTIL=#{until_date}T235959Z"
    end

    event.recurrence = [ rrule ]
  end

  def handle_recurring_event_update(event, calendar_id)
    return event.id unless event.recurring_event_id.present?

    if params[:update_type] == "all"
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
      event.attendees = params[:attendees].split(",").map(&:strip).map { |email|
        Google::Apis::CalendarV3::EventAttendee.new(email: email)
      }
    end

    add_recurrence_rule(event) if params[:recurring_days].present?
  end

  def handle_auth_error
    session[:authorization] = nil
    current_user&.clear_google_calendar_auth
    redirect_to redirect_calendars_path, alert: "Sessão expirada. Por favor, faça login novamente."
  end
end
