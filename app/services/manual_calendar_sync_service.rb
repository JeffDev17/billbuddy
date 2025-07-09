# Service to handle manual calendar synchronization
class ManualCalendarSyncService
  def initialize(user)
    @user = user
    @google_sync = GoogleCalendarSyncService.new(user)
  end

  def sync_all_unsynced_appointments
    appointments = unsynced_appointments
    sync_appointments_batch(appointments)
  end

  def sync_upcoming_appointments(weeks_ahead: 4)
    appointments = upcoming_unsynced_appointments(weeks_ahead)
    sync_appointments_batch(appointments)
  end

  def sync_customer_appointments(customer)
    appointments = customer.unsynced_appointments
    sync_appointments_batch(appointments)
  end

  def sync_customer_upcoming_appointments(customer, weeks_ahead: 4)
    appointments = customer.unsynced_appointments.where(
      scheduled_at: Time.current..weeks_ahead.weeks.from_now
    )
    sync_appointments_batch(appointments)
  end

  def sync_selected_customers_upcoming(customers, weeks_ahead: 4)
    appointments = upcoming_unsynced_appointments_for_customers(customers, weeks_ahead)
    sync_appointments_batch(appointments)
  end

  def sync_selected_customers_all(customers)
    appointments = unsynced_appointments_for_customers(customers)
    sync_appointments_batch(appointments)
  end

  def sync_single_appointment(appointment)
    return { success: false, error: "Appointment already synced" } if appointment.synced_to_calendar?
    return { success: false, error: "Google Calendar not authorized" } unless @user.google_calendar_authorized?

    if @google_sync.sync_appointment(appointment)
      { success: true, synced: 1, errors: [] }
    else
      { success: false, synced: 0, errors: [ "Failed to sync appointment" ] }
    end
  end

  def sync_statistics
    total_appointments = user_scheduled_appointments.count
    synced_appointments = user_scheduled_appointments.where.not(google_event_id: nil).count

    {
      total: total_appointments,
      synced: synced_appointments,
      unsynced: total_appointments - synced_appointments,
      sync_percentage: total_appointments > 0 ? (synced_appointments.to_f / total_appointments * 100).round(1) : 0
    }
  end

  private

  def sync_appointments_batch(appointments)
    return { success: false, error: "Google Calendar not authorized" } unless @user.google_calendar_authorized?

    synced_count = 0
    errors = []

    appointments.find_each do |appointment|
      if @google_sync.sync_appointment(appointment)
        synced_count += 1
      else
        errors << "Failed to sync #{appointment.customer.name} - #{appointment.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
      end
    end

    { success: synced_count > 0, synced: synced_count, errors: errors }
  end

  def unsynced_appointments
    user_scheduled_appointments.where(google_event_id: nil)
  end

  def upcoming_unsynced_appointments(weeks_ahead)
    unsynced_appointments.where(
      scheduled_at: Time.current..weeks_ahead.weeks.from_now
    )
  end

  def user_scheduled_appointments
    @user_scheduled_appointments ||= Appointment.joins(:customer)
                                                .where(customers: { user_id: @user.id })
                                                .where(status: "scheduled")
                                                .includes(:customer)
  end

  def upcoming_unsynced_appointments_for_customers(customers, weeks_ahead)
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .where(customer: customers)
               .where(google_event_id: nil, status: "scheduled")
               .where(scheduled_at: Time.current..weeks_ahead.weeks.from_now)
               .includes(:customer)
  end

  def unsynced_appointments_for_customers(customers)
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .where(customer: customers)
               .where(google_event_id: nil, status: "scheduled")
               .includes(:customer)
  end
end
