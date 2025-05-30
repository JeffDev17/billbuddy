# Module for Google Calendar API client setup
module GoogleCalendarClient
  private

  def setup_calendar_service(user)
    authorization = user.session_authorization
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

class GoogleCalendarSyncService
  include GoogleCalendarClient

  def initialize(user)
    @user = user
    @service = setup_calendar_service(user)
  end

  # Sync a single appointment to Google Calendar
  def sync_appointment(appointment)
    return false unless @service

    begin
      event = build_event_from_appointment(appointment)
      google_event = @service.insert_event("primary", event)

      # Store the Google event ID in the appointment
      appointment.update!(google_event_id: google_event.id)

      true
    rescue Google::Apis::Error => e
      Rails.logger.error "Failed to sync appointment #{appointment.id}: #{e.message}"
      false
    end
  end

  # Sync all scheduled appointments for a customer
  def sync_customer_appointments(customer)
    appointments = customer.appointments.where(status: "scheduled", google_event_id: nil)
    synced_count = 0

    appointments.each do |appointment|
      if sync_appointment(appointment)
        synced_count += 1
      end
    end

    synced_count
  end

  # Sync all scheduled appointments for the user
  def sync_all_scheduled_appointments
    appointments = @user.customers
                        .joins(:appointments)
                        .merge(Appointment.where(status: "scheduled", google_event_id: nil))

    synced_count = 0
    appointments.each do |customer|
      synced_count += sync_customer_appointments(customer)
    end

    synced_count
  end

  # Update an existing Google Calendar event
  def update_appointment_event(appointment)
    return false unless @service && appointment.google_event_id

    begin
      event = @service.get_event("primary", appointment.google_event_id)
      update_event_from_appointment(event, appointment)
      @service.update_event("primary", appointment.google_event_id, event)

      true
    rescue Google::Apis::Error => e
      Rails.logger.error "Failed to update appointment #{appointment.id}: #{e.message}"
      false
    end
  end

  # Delete an event from Google Calendar
  def delete_appointment_event(appointment)
    return false unless @service && appointment.google_event_id

    begin
      @service.delete_event("primary", appointment.google_event_id)
      appointment.update!(google_event_id: nil)

      true
    rescue Google::Apis::Error => e
      Rails.logger.error "Failed to delete appointment #{appointment.id}: #{e.message}"
      false
    end
  end

  # Batch sync appointments for a date range
  def sync_appointments_for_period(start_date, end_date)
    appointments = @user.customers
                        .joins(:appointments)
                        .merge(
                          Appointment.where(
                            status: "scheduled",
                            google_event_id: nil,
                            scheduled_at: start_date.beginning_of_day..end_date.end_of_day
                          )
                        )

    synced_count = 0
    appointments.find_each do |customer|
      customer.appointments
              .where(status: "scheduled", google_event_id: nil, scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
              .each do |appointment|
        if sync_appointment(appointment)
          synced_count += 1
        end
      end
    end

    synced_count
  end

  private

  def build_event_from_appointment(appointment)
    customer = appointment.customer
    start_time = appointment.scheduled_at
    end_time = start_time + appointment.duration.hours

    Google::Apis::CalendarV3::Event.new(
      summary: customer.name,
      description: build_event_description(appointment),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      attendees: customer.email.present? ? [
        Google::Apis::CalendarV3::EventAttendee.new(email: customer.email)
      ] : [],
      reminders: { use_default: true },
      extended_properties: {
        private: {
          billbuddy_appointment_id: appointment.id.to_s,
          customer_id: customer.id.to_s,
          duration: appointment.duration.to_s
        }
      }
    )
  end

  def update_event_from_appointment(event, appointment)
    customer = appointment.customer
    start_time = appointment.scheduled_at
    end_time = start_time + appointment.duration.hours

    event.summary = customer.name
    event.description = build_event_description(appointment)
    event.start.date_time = start_time.iso8601
    event.end.date_time = end_time.iso8601

    if customer.email.present?
      event.attendees = [ Google::Apis::CalendarV3::EventAttendee.new(email: customer.email) ]
    end
  end

  def build_event_description(appointment)
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
end
