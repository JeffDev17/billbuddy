class AppointmentSyncOperationsService
  def initialize(user)
    @user = user
  end

  def sync_all_appointments
    result = manual_sync_service.sync_all_unsynced_appointments

    if result[:success]
      {
        success: true,
        message: "#{result[:synced]} compromissos sincronizados com o Google Calendar."
      }
    else
      {
        success: false,
        message: result[:error] || "Erro ao sincronizar compromissos."
      }
    end
  end

  def sync_upcoming_appointments(weeks_ahead = 4)
    result = manual_sync_service.sync_upcoming_appointments(weeks_ahead: weeks_ahead)

    if result[:success]
      {
        success: true,
        message: "#{result[:synced]} compromissos futuros sincronizados com o Google Calendar."
      }
    else
      {
        success: false,
        message: result[:error] || "Erro ao sincronizar compromissos futuros."
      }
    end
  end

  def prepare_sync_review(scope, weeks_ahead = 4, customer_id = nil, customer_ids = [])
    case scope
    when "all"
      unsynced_appointments_for_review
    when "upcoming"
      upcoming_unsynced_appointments_for_review(weeks_ahead)
    when "customer"
      customer = find_customer(customer_id)
      customer.unsynced_appointments.includes(:customer).order(:scheduled_at)
    when "customer_upcoming"
      customer = find_customer(customer_id)
      customer.upcoming_unsynced_appointments(weeks_ahead).includes(:customer).order(:scheduled_at)
    when "selected_customers"
      customers = current_user_customers.where(id: customer_ids)
      upcoming_unsynced_appointments_for_customers(customers, weeks_ahead)
    when "selected_customers_all"
      customers = current_user_customers.where(id: customer_ids)
      unsynced_appointments_for_customers(customers)
    else
      []
    end
  end

  def confirm_sync(scope, weeks_ahead = 4, customer_id = nil, customer_ids = [])
    result = case scope
    when "all"
      manual_sync_service.sync_all_unsynced_appointments
    when "upcoming"
      manual_sync_service.sync_upcoming_appointments(weeks_ahead: weeks_ahead)
    when "customer"
      customer = find_customer(customer_id)
      manual_sync_service.sync_customer_appointments(customer)
    when "customer_upcoming"
      customer = find_customer(customer_id)
      manual_sync_service.sync_customer_upcoming_appointments(customer, weeks_ahead: weeks_ahead)
    when "selected_customers"
      customers = current_user_customers.where(id: customer_ids)
      manual_sync_service.sync_selected_customers_upcoming(customers, weeks_ahead: weeks_ahead)
    when "selected_customers_all"
      customers = current_user_customers.where(id: customer_ids)
      manual_sync_service.sync_selected_customers_all(customers)
    else
      { success: false, error: "Scope inválido" }
    end

    if result[:success]
      {
        success: true,
        message: "#{result[:synced]} compromissos sincronizados com sucesso!"
      }
    else
      {
        success: false,
        message: result[:error] || "Erro ao sincronizar compromissos."
      }
    end
  end

  def calculate_sync_stats(appointments)
    grouped = appointments.group_by { |apt| apt.scheduled_at.to_date }
    weeks = group_by_week(appointments)

    {
      total_appointments: appointments.count,
      total_days: grouped.keys.count,
      total_weeks: weeks.keys.count,
      appointments_by_date: grouped.transform_values(&:count),
      appointments_by_week: weeks.transform_values(&:count)
    }
  end

  private

  def manual_sync_service
    @manual_sync_service ||= ManualCalendarSyncService.new(@user)
  end

  def current_user_customers
    @user.customers
  end

  def find_customer(customer_id)
    current_user_customers.find(customer_id)
  end

  def unsynced_appointments_for_review
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .where(google_event_id: nil)
               .where(status: "scheduled")
               .includes(:customer)
               .order(:scheduled_at)
  end

  def upcoming_unsynced_appointments_for_review(weeks_ahead)
    unsynced_appointments_for_review.where(
      scheduled_at: Time.current..weeks_ahead.weeks.from_now
    )
  end

  def upcoming_unsynced_appointments_for_customers(customers, weeks_ahead)
    Appointment.joins(:customer)
               .where(customers: { id: customers.pluck(:id) })
               .where(google_event_id: nil)
               .where(status: "scheduled")
               .where(scheduled_at: Time.current..weeks_ahead.weeks.from_now)
               .includes(:customer)
               .order(:scheduled_at)
  end

  def unsynced_appointments_for_customers(customers)
    Appointment.joins(:customer)
               .where(customers: { id: customers.pluck(:id) })
               .where(google_event_id: nil)
               .where(status: "scheduled")
               .includes(:customer)
               .order(:scheduled_at)
  end

  def group_by_week(appointments)
    appointments.group_by { |apt| apt.scheduled_at.beginning_of_week }
  end
end
