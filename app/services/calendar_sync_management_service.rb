# Service to handle calendar synchronization and management
class CalendarSyncManagementService
  def initialize(user)
    @user = user
  end

  def sync_appointment(appointment)
    sync_service = GoogleCalendarSyncService.new(@user)
    sync_service.sync_appointment(appointment)
  end

  def bulk_sync(params)
    sync_service = GoogleCalendarSyncService.new(@user)

    if params[:sync_all] == "true"
      handle_sync_all(sync_service, params)
    else
      handle_period_sync(sync_service, params)
    end
  end

  def sync_customer_recurring(customer)
    sync_service = GoogleCalendarSyncService.new(@user)
    sync_service.sync_customer_recurring_appointments(customer)
  end

  def daily_schedule_data(date)
    appointments = user_appointments.where(
      scheduled_at: date.beginning_of_day..date.end_of_day,
      status: "scheduled"
    ).includes(:customer)

    {
      appointments: appointments,
      total_hours: appointments.sum(:duration),
      total_earnings: calculate_daily_earnings(appointments),
      first_appointment: appointments.order(:scheduled_at).first&.scheduled_at,
      last_appointment: appointments.order(:scheduled_at).last&.scheduled_at
    }
  end

  def sync_statistics
    total_appointments = user_appointments.where(status: "scheduled").count
    synced_appointments = user_appointments.where(status: "scheduled").where.not(google_calendar_event_id: nil).count

    {
      total: total_appointments,
      synced: synced_appointments,
      unsynced: total_appointments - synced_appointments,
      sync_percentage: total_appointments > 0 ? (synced_appointments.to_f / total_appointments * 100).round(1) : 0
    }
  end

  def appointments_for_date(date)
    user_appointments.where(
      scheduled_at: date.beginning_of_day..date.end_of_day
    ).includes(:customer).order(:scheduled_at)
  end

  private

  def handle_sync_all(sync_service, params)
    if params[:as_recurring] == "true"
      sync_service.sync_all_scheduled_appointments_as_recurring
    else
      sync_service.sync_all_scheduled_appointments
    end
  end

  def handle_period_sync(sync_service, params)
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current

    if params[:as_recurring] == "true"
      sync_service.sync_appointments_for_period_as_recurring(start_date, end_date)
    else
      sync_service.sync_appointments_for_period(start_date, end_date)
    end
  end

  def user_appointments
    @user_appointments ||= Appointment.joins(:customer)
                                     .where(customers: { user_id: @user.id })
                                     .includes(:customer)
  end

  def calculate_daily_earnings(appointments)
    appointments.sum do |appointment|
      appointment.duration * appointment.customer.effective_hourly_rate
    end
  end
end
