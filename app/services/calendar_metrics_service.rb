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

  def calculate_comprehensive_stats(period = nil)
    # Use provided period or default to current month
    calculation_period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
    past_appointments = current_user_appointments.where(scheduled_at: ..Time.current)
    month_appointments = current_user_appointments.where(scheduled_at: calculation_period)

    cancelled_count = month_appointments.where(status: "cancelled").count
    no_show_count = month_appointments.where(status: "no_show").count

    {
      cancelled: cancelled_count,
      no_show: no_show_count,
      cancellation_rate: calculate_cancellation_rate(calculation_period),
      completion_rate: calculate_completion_rate(calculation_period),
      completion_metrics: calculate_completion_metrics(past_appointments),
      average_ticket: calculate_average_ticket(month_appointments.where(status: "completed")),
      month_earnings: calculate_month_earnings(month_appointments.where(status: "completed"))
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

  def calculate_monthly_trends_from_date(base_date)
    trends = []
    (0..5).each do |i|
      # Use the base_date instead of current date, going backwards i months
      target_month = base_date.beginning_of_month - i.months
      month_start = target_month.beginning_of_month
      month_end = target_month.end_of_month

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

  def calculate_weekly_performance_from_date(base_date)
    weeks = []
    (0..3).each do |i|
      # Calculate weeks relative to the base_date's month instead of current date
      base_week = base_date.beginning_of_month.beginning_of_week
      week_start = base_week - i.weeks
      week_end = week_start.end_of_week

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
      appointment.effective_appointment_rate * appointment.duration
    end

    # Calculate potential earnings from scheduled appointments only
    scheduled_appointments = all_appointments.where(status: "scheduled")
    potential_earnings = scheduled_appointments.sum do |appointment|
      appointment.effective_appointment_rate * appointment.duration
    end

    {
      total_if_all_completed: total_if_all_completed,
      potential: potential_earnings
    }
  end



  def cancellation_revenue(period = nil)
    calculation_period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
    cancelled_with_revenue = current_user_appointments.cancelled_with_revenue
                                                     .where(scheduled_at: calculation_period)
                                                     .includes(:customer)

    total = 0
    cancelled_with_revenue.each do |appointment|
      begin
        rate = appointment.effective_appointment_rate
        duration = appointment.duration || 1.0
        total += rate * duration
      rescue => e
        Rails.logger.error "Error calculating cancellation revenue for appointment #{appointment.id}: #{e.message}"
        next
      end
    end
    total
  end

  def cancellation_metrics(period = nil)
    calculation_period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
    period_appointments = current_user_appointments.where(scheduled_at: calculation_period)

    total_cancelled = period_appointments.cancelled.count
    pending_reschedule = period_appointments.cancelled_pending_reschedule.count
    with_revenue = period_appointments.cancelled_with_revenue.count
    standard = period_appointments.where(status: "cancelled", cancellation_type: "standard").count

    {
      total_cancelled: total_cancelled,
      pending_reschedule: pending_reschedule,
      with_revenue: with_revenue,
      standard: standard,
      revenue_from_cancellations: cancellation_revenue(period)
    }
  end

  # Método para calcular receita total (concluídos + cancelamentos que geram receita)
  def calculate_total_revenue_including_cancellations(period = nil)
    calculation_period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
    completed_appointments = current_user_appointments.where(status: "completed", scheduled_at: calculation_period)

    # Receita de appointments concluídos
    completed_revenue = calculate_month_earnings(completed_appointments)

    # Receita de cancelamentos
    cancellation_revenue_amount = cancellation_revenue(period)

    completed_revenue + cancellation_revenue_amount
  end

  # Método para calcular lucro semanal do mês
  def calculate_weekly_revenue_for_month(base_date)
    month_start = base_date.beginning_of_month
    month_end = base_date.end_of_month

    weeks = []
    current_week_start = month_start.beginning_of_week

    while current_week_start <= month_end
      week_end = [ current_week_start.end_of_week, month_end ].min
      week_period = current_week_start.beginning_of_day..week_end.end_of_day

      # Calcular receita da semana incluindo cancelamentos
      week_revenue = calculate_total_revenue_including_cancellations(week_period)

      weeks << {
        week_label: "#{current_week_start.strftime('%d/%m')} - #{week_end.strftime('%d/%m')}",
        week_start: current_week_start,
        week_end: week_end,
        revenue: week_revenue.round(2)
      }

      current_week_start += 1.week
    end

    weeks
  end

  private

  def current_user_appointments
    @current_user_appointments ||= Appointment.joins(:customer).where(customers: { user_id: @user.id })
  end

  def calculate_cancellation_rate(period = nil)
    calculation_period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
    total_appointments = current_user_appointments.where(scheduled_at: calculation_period).count
    cancelled_appointments = current_user_appointments.where(scheduled_at: calculation_period, status: "cancelled").count

    return 0 if total_appointments == 0
    ((cancelled_appointments.to_f / total_appointments) * 100).round(1)
  end

  def calculate_completion_rate(period = nil)
    calculation_period = period || (Date.current.beginning_of_month..Date.current.end_of_month)
    total_appointments = current_user_appointments.where(scheduled_at: calculation_period).count
    completed_appointments = current_user_appointments.where(scheduled_at: calculation_period, status: "completed").count

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
        rate = appointment.effective_appointment_rate
        duration = appointment.duration || 1.0
        total += rate * duration
      rescue => e
        Rails.logger.error "Error calculating earnings for appointment #{appointment.id}: #{e.message}"
        next
      end
    end
    total
  end
end
