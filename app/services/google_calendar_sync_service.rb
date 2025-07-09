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

  # Main sync methods
  def sync_appointment(appointment)
    return false unless @service
    execute_sync { create_individual_event(appointment) }
  end

  def sync_customer_appointments(customer)
    sync_appointments_collection(customer.unsynced_appointments)
  end

  def sync_all_scheduled_appointments
    sync_appointments_collection(user_unsynced_appointments)
  end

  def sync_all_appointments
    sync_appointments_collection(user_unsynced_all_appointments)
  end

  def sync_appointments_for_period(start_date, end_date)
    appointments = period_appointments(start_date, end_date)
    sync_appointments_collection(appointments)
  end

  def sync_all_appointments_for_period(start_date, end_date)
    appointments = period_all_appointments(start_date, end_date)
    sync_appointments_collection(appointments)
  end

  # Recurring sync methods
  def sync_customer_recurring_appointments(customer, date_range = nil)
    appointments = customer.unsynced_appointments
    appointments = appointments.where(scheduled_at: date_range) if date_range
    sync_as_recurring_events(appointments)
  end

  def sync_all_scheduled_appointments_as_recurring
    customer_groups = user_unsynced_appointments.includes(:customer).group_by(&:customer)
    customer_groups.sum { |customer, appointments| sync_as_recurring_events(appointments) }
  end

  def sync_all_appointments_as_recurring
    customer_groups = user_unsynced_all_appointments.includes(:customer).group_by(&:customer)
    customer_groups.sum { |customer, appointments| sync_as_recurring_events(appointments) }
  end

  def sync_appointments_for_period_as_recurring(start_date, end_date)
    appointments = period_appointments(start_date, end_date)
    sync_as_recurring_events(appointments)
  end

  def sync_all_appointments_for_period_as_recurring(start_date, end_date)
    appointments = period_all_appointments(start_date, end_date)
    customer_groups = appointments.includes(:customer).group_by(&:customer)
    customer_groups.sum { |customer, appointments| sync_as_recurring_events(appointments) }
  end

  # CRUD operations
  def update_appointment_event(appointment)
    return false unless @service && appointment.google_event_id
    execute_sync { update_existing_event(appointment) }
  end

  def delete_appointment_event(appointment)
    return false unless @service && appointment.google_event_id
    execute_sync { delete_single_event(appointment) }
  end

  def delete_recurring_event_series(appointment)
    return false unless @service && appointment.google_event_id && appointment.part_of_recurring_series?
    execute_sync { delete_recurring_series(appointment) }
  end

  private

  # Core sync logic
  def sync_appointments_collection(appointments)
    appointments.sum { |appointment| sync_appointment(appointment) ? 1 : 0 }
  end

    def sync_as_recurring_events(appointments)
    grouped_appointments = RecurringAppointmentGrouper.new(appointments).group_by_pattern

    synced_count = 0
    grouped_appointments.each do |group_key, appointment_group|
      if appointment_group.size >= 2
        synced_count += sync_recurring_group(appointment_group)
      else
        # Single appointments - sync individually
        synced_count += sync_appointments_collection(appointment_group)
      end
    end
    synced_count
  end

    def sync_recurring_group(appointments)
    pattern = RecurringPatternDetector.new(appointments).detect
    return sync_appointments_collection(appointments) unless pattern

    execute_sync do
      create_recurring_event(appointments, pattern)
      appointments.size
    end || sync_appointments_collection(appointments) # Fallback to individual
  end

  # Event creation
  def create_individual_event(appointment)
    event = GoogleCalendarEventBuilder.individual(appointment)
    google_event = @service.insert_event("primary", event)
    appointment.update!(google_event_id: google_event.id)
    true
  end

  def create_recurring_event(appointments, pattern)
    event = GoogleCalendarEventBuilder.recurring(appointments, pattern)
    google_event = @service.insert_event("primary", event)

    appointments.each do |appointment|
      appointment.update!(google_event_id: google_event.id, is_recurring_event: true)
    end
    true
  end

  def update_existing_event(appointment)
    event = @service.get_event("primary", appointment.google_event_id)
    GoogleCalendarEventBuilder.update_from_appointment(event, appointment)
    @service.update_event("primary", appointment.google_event_id, event)
    true
  end

  def delete_single_event(appointment)
    @service.delete_event("primary", appointment.google_event_id)
    appointment.update!(google_event_id: nil)
    true
  end

  def delete_recurring_series(appointment)
    @service.delete_event("primary", appointment.google_event_id)

    appointment.customer.appointments
               .where(google_event_id: appointment.google_event_id, is_recurring_event: true)
               .update_all(google_event_id: nil, is_recurring_event: false)
    true
  end

  # Query helpers
  def user_unsynced_appointments
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .unsynced_scheduled
  end

  def user_unsynced_all_appointments
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .unsynced_all
  end

  def period_appointments(start_date, end_date)
    user_unsynced_appointments.where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
  end

  def period_all_appointments(start_date, end_date)
    user_unsynced_all_appointments.where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
  end

  # Error handling wrapper
  def execute_sync
    yield
  rescue Google::Apis::Error => e
    Rails.logger.error "Google Calendar sync failed: #{e.message}"
    false
  end
end
