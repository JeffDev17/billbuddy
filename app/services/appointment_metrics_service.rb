class AppointmentMetricsService
  def initialize(user, period = nil)
    @user = user
    @period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
  end

  # Earnings calculations
  def total_earnings
    calculate_earnings_for_appointments(completed_appointments)
  end

  def projected_earnings
    calculate_earnings_for_appointments(scheduled_appointments) + total_earnings
  end

  def earnings_by_customer
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .where(status: "completed")
               .where(scheduled_at: @period)
               .joins("LEFT JOIN customer_credits ON customers.id = customer_credits.customer_id")
               .joins("LEFT JOIN service_packages ON customer_credits.service_package_id = service_packages.id")
               .group("customers.name")
               .sum("appointments.duration * COALESCE(service_packages.price / NULLIF(service_packages.hours, 0), 50)")
  end

  # Class distribution
  def classes_this_month
    appointments_in_period.count
  end

  def completed_classes_count
    completed_appointments.count
  end

  def scheduled_classes_count
    scheduled_appointments.count
  end

  # Credit analysis
  def customers_needing_credits_soon(threshold_hours = 5)
    @user.customers.credit
         .joins(:customer_credits)
         .where("customer_credits.remaining_hours <= ?", threshold_hours)
         .where("customer_credits.remaining_hours > 0")
         .distinct
  end

  def credit_consumption_rate
    last_month_consumption = calculate_last_month_consumption
    return 0 if last_month_consumption.zero?

    current_month_consumption = calculate_current_month_consumption
    ((current_month_consumption - last_month_consumption) / last_month_consumption.to_f * 100).round(2)
  end

  # Workload analysis
  def busiest_days
    appointments_in_period
      .group_by { |apt| apt.scheduled_at.strftime("%A") }
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .to_h
  end

  def daily_schedule(date = Date.current)
    appointments = Appointment.joins(:customer)
                              .where(customers: { user_id: @user.id })
                              .scheduled_for_date(date)
                              .includes(:customer)
                              .order(:scheduled_at)

    {
      date: date,
      total_classes: appointments.count,
      total_hours: appointments.sum(:duration),
      appointments: appointments.map do |appointment|
        {
          time: appointment.scheduled_at.strftime("%H:%M"),
          customer: appointment.customer.name,
          duration: appointment.duration,
          status: appointment.status,
          synced: appointment.synced_to_calendar?
        }
      end
    }
  end

  # Forecasting
  def monthly_class_forecast
    weekly_average = weekly_class_average
    weeks_in_month = 4.33 # Average weeks per month
    (weekly_average * weeks_in_month).round
  end

  def revenue_forecast
    avg_hourly_rate = calculate_average_hourly_rate
    forecasted_classes = monthly_class_forecast
    avg_duration = calculate_average_duration

    (forecasted_classes * avg_duration * avg_hourly_rate).round(2)
  end

  # Calendar sync status
  def sync_status
    total = appointments_in_period.count
    synced = appointments_in_period.synced_to_calendar.count

    {
      total_appointments: total,
      synced_appointments: synced,
      pending_sync: total - synced,
      sync_percentage: total.zero? ? 0 : ((synced.to_f / total) * 100).round(2)
    }
  end

  # Summary report
  def monthly_summary
    {
      period: @period,
      earnings: {
        completed: total_earnings,
        projected: projected_earnings,
        by_customer: earnings_by_customer.first(5)
      },
      classes: {
        total: classes_this_month,
        completed: completed_classes_count,
        scheduled: scheduled_classes_count,
        forecast: monthly_class_forecast
      },
      credits: {
        customers_low_credits: customers_needing_credits_soon.count,
        consumption_rate: credit_consumption_rate
      },
      workload: {
        busiest_days: busiest_days.first(3),
        total_hours: appointments_in_period.sum(:duration)
      },
      sync_status: sync_status
    }
  end

  private

  def appointments_in_period
    @appointments_in_period ||= Appointment.joins(:customer)
                                           .where(customers: { user_id: @user.id })
                                           .where(scheduled_at: @period)
  end

  def completed_appointments
    appointments_in_period.where(status: "completed")
  end

  def scheduled_appointments
    appointments_in_period.where(status: "scheduled")
  end

  def calculate_earnings_for_appointments(appointments_relation)
    # Calculate earnings by dividing package price by hours to get hourly rate
    appointments_relation.joins("LEFT JOIN customer_credits ON customers.id = customer_credits.customer_id")
                        .joins("LEFT JOIN service_packages ON customer_credits.service_package_id = service_packages.id")
                        .sum("appointments.duration * COALESCE(service_packages.price / NULLIF(service_packages.hours, 0), 50)") # 50 as default rate
  end

  def calculate_last_month_consumption
    last_month = (Date.current - 1.month).beginning_of_month..(Date.current - 1.month).end_of_month
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .where(scheduled_at: last_month, status: "completed")
               .sum(:duration)
  end

  def calculate_current_month_consumption
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .where(scheduled_at: current_month, status: "completed")
               .sum(:duration)
  end

  def weekly_class_average
    # Calculate based on last 4 weeks
    last_4_weeks = 4.weeks.ago..Date.current
    total_classes = Appointment.joins(:customer)
                               .where(customers: { user_id: @user.id })
                               .where(scheduled_at: last_4_weeks)
                               .count

    total_classes / 4.0
  end

  def calculate_average_hourly_rate
    # This would depend on your pricing structure
    # For now, return a default or calculate from service packages
    50.0 # Default rate - should be calculated from actual data
  end

  def calculate_average_duration
    appointments_in_period.average(:duration) || 1.0
  end
end
