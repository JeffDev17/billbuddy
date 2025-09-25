# Service to handle appointment filtering and querying
class AppointmentFilterService
  def initialize(user)
    @user = user
  end

  def call(params = {})
    appointments = base_scope

    appointments = filter_by_status(appointments, params[:status])
    appointments = filter_by_cancellation_type(appointments, params[:cancellation_type])
    appointments = filter_by_month_year(appointments, params[:month], params[:year])
    appointments = filter_by_date_range(appointments, params[:start_date], params[:end_date])
    appointments = filter_by_customer(appointments, params[:customer_id])
    appointments = filter_by_search(appointments, params[:search])

    apply_sorting(appointments, params[:sort_order])
  end

  def filter_stats
    {
      total: base_scope.count,
      scheduled: base_scope.where(status: "scheduled").count,
      completed: base_scope.where(status: "completed").count,
      cancelled: base_scope.where(status: "cancelled").count,
      no_show: base_scope.where(status: "no_show").count,
      today: base_scope.scheduled_for_date(Date.current).count,
      this_week: base_scope.where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week).count,
      future: base_scope.future.count
    }
  end

  def for_date(date)
    base_scope.where(
      scheduled_at: date.beginning_of_day..date.end_of_day
    )
  end

  def unsynced_scheduled
    base_scope.unsynced_scheduled
  end

  def for_period(start_date, end_date)
    base_scope.where(
      scheduled_at: start_date.beginning_of_day..end_date.end_of_day
    )
  end

  private

  def base_scope
    @base_scope ||= Appointment.joins(:customer).where(customers: { user_id: @user.id }).includes(:customer)
  end

  def filter_by_status(appointments, status)
    return appointments if status.blank?
    appointments.where(status: status)
  end

  def filter_by_cancellation_type(appointments, cancellation_type)
    return appointments if cancellation_type.blank?
    appointments.where(cancellation_type: cancellation_type)
  end

  def filter_by_date_range(appointments, start_date, end_date)
    appointments = filter_by_start_date(appointments, start_date)
    filter_by_end_date(appointments, end_date)
  end

  def filter_by_start_date(appointments, start_date)
    return appointments if start_date.blank?
    parsed_date = Date.parse(start_date).beginning_of_day
    appointments.where("scheduled_at >= ?", parsed_date)
  end

  def filter_by_end_date(appointments, end_date)
    return appointments if end_date.blank?
    parsed_date = Date.parse(end_date).end_of_day
    appointments.where("scheduled_at <= ?", parsed_date)
  end

  def filter_by_customer(appointments, customer_id)
    return appointments if customer_id.blank?
    appointments.where(customer_id: customer_id)
  end

  def filter_by_month_year(appointments, month, year)
    return appointments if month.blank? || year.blank?

    start_date = Date.new(year.to_i, month.to_i, 1).beginning_of_month
    end_date = start_date.end_of_month

    appointments.where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
  end

    def filter_by_search(appointments, search_term)
    return appointments if search_term.blank?

    appointments.joins(:customer).where(
                  "customers.name ILIKE ? OR appointments.notes ILIKE ?",
                  "%#{search_term}%",
                  "%#{search_term}%"
                )
  end

  def apply_sorting(appointments, sort_order)
    case sort_order
    when "scheduled_first"
      # Show scheduled appointments first, then by date (earliest to latest)
      # Use Ruby sorting to avoid SQL complexity
      appointments.order(scheduled_at: :asc).to_a.sort_by do |appointment|
        [ appointment.status == "scheduled" ? 0 : 1, appointment.scheduled_at ]
      end
    when "earliest_first"
      appointments.order(scheduled_at: :asc)
    when "latest_first"
      appointments.order(scheduled_at: :desc)
    when "customer_name"
      appointments.joins(:customer).order("customers.name ASC, appointments.scheduled_at ASC")
    when "status"
      appointments.order("appointments.status ASC, appointments.scheduled_at ASC")
    else
      # Default to scheduled first (new default behavior)
      # Use Ruby sorting to avoid SQL complexity
      appointments.order(scheduled_at: :asc).to_a.sort_by do |appointment|
        [ appointment.status == "scheduled" ? 0 : 1, appointment.scheduled_at ]
      end
    end
  end
end
