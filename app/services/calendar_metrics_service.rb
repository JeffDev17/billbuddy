class CalendarMetricsService
  def initialize(user)
    @user = user
  end

  def calculate_daily_schedule(date)
    appointments = current_user_appointments.where(
      scheduled_at: date.beginning_of_day..date.end_of_day
    ).includes(:customer).order(:scheduled_at)

    appointment_details = appointments.map do |appointment|
      {
        status: appointment.status,
        time: appointment.scheduled_at.strftime("%H:%M"),
        customer: appointment.customer.name,
        duration: appointment.duration,
        synced: appointment.google_event_id.present?
      }
    end

    {
      appointments: appointment_details,
      total_classes: appointments.count,
      total_hours: appointments.sum(&:duration).round(1),
      appointments_by_hour: appointments.group_by { |apt| apt.scheduled_at.hour },
      busy_hours: appointments.pluck(:scheduled_at).map(&:hour).uniq.sort
    }
  end

  def calculate_sync_statistics
    total_appointments = current_user_appointments.where(status: "scheduled").count
    synced_appointments = current_user_appointments.where(status: "scheduled").where.not(google_event_id: nil).count
    unsynced_appointments = total_appointments - synced_appointments

    {
      total: total_appointments,
      synced: synced_appointments,
      unsynced: unsynced_appointments,
      sync_percentage: total_appointments > 0 ? ((synced_appointments.to_f / total_appointments) * 100).round(1) : 0
    }
  end

  def calculate_comprehensive_stats
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    past_appointments = current_user_appointments.where(scheduled_at: ..Time.current)
    current_month_appointments = current_user_appointments.where(scheduled_at: current_month)

    cancelled_count = current_month_appointments.where(status: "cancelled").count
    no_show_count = current_month_appointments.where(status: "no_show").count

    {
      cancelled: cancelled_count,
      no_show: no_show_count,
      cancellation_rate: calculate_cancellation_rate,
      completion_rate: calculate_completion_rate,
      completion_metrics: calculate_completion_metrics(past_appointments),
      average_ticket: calculate_average_ticket(past_appointments.where(status: "completed")),
      month_earnings: calculate_month_earnings(current_month_appointments.where(status: "completed"))
    }
  end

  def calculate_monthly_trends
    trends = []
    (0..5).each do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month

      appointments = current_user_appointments.where(scheduled_at: month_start..month_end)

      trends << {
        month_name: month_start.strftime("%B %Y"),
        total: appointments.count,
        completed: appointments.where(status: "completed").count,
        cancelled: appointments.where(status: "cancelled").count,
        no_show: appointments.where(status: "no_show").count,
        earnings: calculate_month_earnings(appointments.where(status: "completed"))
      }
    end
    trends.reverse
  end

  def calculate_weekly_performance
    weeks = []
    (0..3).each do |i|
      week_start = i.weeks.ago.beginning_of_week
      week_end = i.weeks.ago.end_of_week

      appointments = current_user_appointments.where(scheduled_at: week_start..week_end)

      weeks << {
        week_label: "#{week_start.strftime('%d/%m')} - #{week_end.strftime('%d/%m')}",
        total: appointments.count,
        completed: appointments.where(status: "completed").count,
        cancelled: appointments.where(status: "cancelled").count,
        no_show: appointments.where(status: "no_show").count,
        earnings: calculate_month_earnings(appointments.where(status: "completed"))
      }
    end
    weeks.reverse
  end

  def calculate_daily_preview(date)
    appointments = current_user_appointments.where(
      scheduled_at: date.beginning_of_day..date.end_of_day
    ).includes(:customer).order(:scheduled_at)

    appointments.map do |appointment|
      earnings = appointment.customer.effective_hourly_rate * appointment.duration

      {
        status: appointment.status,
        time: appointment.scheduled_at.strftime("%H:%M"),
        customer: appointment.customer.name,
        duration: appointment.duration,
        earnings: earnings,
        synced: appointment.google_event_id.present?,
        appointment: appointment
      }
    end
  end

  def calculate_projected_daily_earnings(date)
    all_appointments = current_user_appointments.where(
      scheduled_at: date.beginning_of_day..date.end_of_day
    ).includes(:customer)

    # Calculate total earnings if all appointments are completed
    total_if_all_completed = all_appointments.sum do |appointment|
      appointment.customer.effective_hourly_rate * appointment.duration
    end

    # Calculate potential earnings from scheduled appointments only
    scheduled_appointments = all_appointments.where(status: "scheduled")
    potential_earnings = scheduled_appointments.sum do |appointment|
      appointment.customer.effective_hourly_rate * appointment.duration
    end

    {
      total_if_all_completed: total_if_all_completed,
      potential: potential_earnings
    }
  end

  private

  def current_user_appointments
    @current_user_appointments ||= Appointment.joins(:customer).where(customers: { user_id: @user.id })
  end

  def calculate_cancellation_rate
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    total_appointments = current_user_appointments.where(scheduled_at: current_month).count
    cancelled_appointments = current_user_appointments.where(scheduled_at: current_month, status: "cancelled").count

    return 0 if total_appointments == 0
    ((cancelled_appointments.to_f / total_appointments) * 100).round(1)
  end

  def calculate_completion_rate
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    total_appointments = current_user_appointments.where(scheduled_at: current_month).count
    completed_appointments = current_user_appointments.where(scheduled_at: current_month, status: "completed").count

    return 0 if total_appointments == 0
    ((completed_appointments.to_f / total_appointments) * 100).round(1)
  end

  def calculate_completion_metrics(past_appointments)
    total_past = past_appointments.count
    completed_past = past_appointments.where(status: "completed").count
    cancelled_past = past_appointments.where(status: "cancelled").count
    no_show_past = past_appointments.where(status: "no_show").count

    return { completion_rate: 0, cancellation_rate: 0, no_show_rate: 0 } if total_past == 0

    {
      completion_rate: ((completed_past.to_f / total_past) * 100).round(1),
      cancellation_rate: ((cancelled_past.to_f / total_past) * 100).round(1),
      no_show_rate: ((no_show_past.to_f / total_past) * 100).round(1)
    }
  end

  def calculate_average_ticket(completed_appointments)
    return 0 if completed_appointments.count == 0

    total_earnings = calculate_month_earnings(completed_appointments)
    (total_earnings / completed_appointments.count).round(2)
  end

  def calculate_month_earnings(completed_appointments)
    total = 0
    completed_appointments.includes(:customer).each do |appointment|
      begin
        rate = appointment.customer.effective_hourly_rate
        duration = appointment.duration || 1.0
        total += rate * duration
      rescue => e
        Rails.logger.error "Error calculating earnings for appointment #{appointment.id}: #{e.message}"
        next
      end
    end
    total.round(2)
  end
end
