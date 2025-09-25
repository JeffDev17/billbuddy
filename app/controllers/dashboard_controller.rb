class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @customers_count = current_user_customers.count
    @active_customers = current_user_customers.active.count
    @total_appointments_today = current_user_appointments.today.count
    @completed_appointments_today = current_user_appointments.today.completed.count

    @selected_date = Date.current
    @daily_completion_data = appointment_completion_service.get_daily_completion_data(@selected_date)
    @todays_appointments = appointment_completion_service.get_completable_appointments(@selected_date)

    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    @weekly_stats = calculate_weekly_stats(week_start, week_end)

    @upcoming_appointments = current_user_appointments.where("scheduled_at > ?", Time.current).includes(:customer).order(:scheduled_at).limit(5)

    @recent_completed = current_user_appointments.completed.includes(:customer).order(completed_at: :desc).limit(5)

    @insights = calculate_revenue_insights

    @low_credit_customers = current_user_customers.credit.joins(:customer_credits).limit(5).where("customer_credits.remaining_hours <= ?", 2).distinct

    @todays_birthdays = current_user_customers.with_birthday_today
    @this_month_birthdays = current_user_customers.with_birthday_this_month.sort_by { |c| c.birthdate.day }

    @business_health = calculate_business_health_metrics
  end

  private

  def current_user_customers
    current_user.customers
  end

  def current_user_appointments
    Appointment.joins(:customer).where(customers: { user_id: current_user.id })
  end

  def appointment_completion_service
    @appointment_completion_service ||= AppointmentCompletionService.new(current_user)
  end

  def calendar_metrics_service
    @calendar_metrics_service ||= CalendarMetricsService.new(current_user)
  end

  def calculate_weekly_stats(week_start, week_end)
    appointments = current_user_appointments.where(
      scheduled_at: week_start.beginning_of_day..week_end.end_of_day
    )

    total_booked = appointments.count
    completed = appointments.completed.count
    scheduled = appointments.scheduled.count
    cancelled = appointments.cancelled.count

    non_cancelled = total_booked - cancelled
    completion_rate = non_cancelled > 0 ?
      (completed.to_f / non_cancelled * 100).round(1) : 0

    cancellation_rate = total_booked > 0 ?
      (cancelled.to_f / total_booked * 100).round(1) : 0

    {
      total: total_booked,
      completed: completed,
      scheduled: scheduled,
      cancelled: cancelled,
      non_cancelled: non_cancelled,
      total_hours: appointments.sum(:duration),
      completion_rate: completion_rate,
      cancellation_rate: cancellation_rate
    }
  end

  def calculate_revenue_insights
    todays_earnings = calculate_earnings_for_period(Date.current.beginning_of_day..Date.current.end_of_day)

    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    weekly_earnings = calculate_earnings_for_period(week_start.beginning_of_day..week_end.end_of_day)

    avg_hourly_rate = calculate_average_hourly_rate
    best_day_this_week = find_best_earning_day_this_week(week_start, week_end)
    pending_payments = calculate_pending_payments

    {
      todays_earnings: todays_earnings,
      weekly_earnings: weekly_earnings,
      average_hourly_rate: avg_hourly_rate,
      best_day_this_week: best_day_this_week,
      pending_payments: pending_payments,
      trending_up: weekly_earnings > 0 && todays_earnings > 0
    }
  end

  def calculate_earnings_for_period(period)
    current_user_appointments
      .completed
      .where(completed_at: period)
      .joins(:customer)
      .sum { |appointment| appointment.duration * appointment.customer.effective_hourly_rate }
      .round(2)
  end

  def calculate_average_hourly_rate
    customers_with_rates = current_user_customers.map(&:effective_hourly_rate)
    return 0 if customers_with_rates.empty?

    (customers_with_rates.sum / customers_with_rates.size).round(2)
  end

  def find_best_earning_day_this_week(week_start, week_end)
    daily_earnings = {}

    (week_start..week_end).each do |date|
      next if date > Date.current

      day_earnings = calculate_earnings_for_period(date.beginning_of_day..date.end_of_day)
      daily_earnings[date] = day_earnings if day_earnings > 0
    end

    return nil if daily_earnings.empty?

    best_date = daily_earnings.max_by { |date, earnings| earnings }
    {
      date: best_date[0],
      amount: best_date[1],
      day_name: best_date[0].strftime("%A")
    }
  end

  def calculate_pending_payments
    Payment.joins(customer: :user)
           .where(users: { id: current_user.id })
           .where(status: "pending")
           .sum(:amount)
           .round(2)
  end

  def calculate_business_health_metrics
    month_start = Date.current.beginning_of_month
    month_end = Date.current.end_of_month
    this_month_appointments = current_user_appointments.where(scheduled_at: month_start.beginning_of_day..month_end.end_of_day)

    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month
    last_month_appointments = current_user_appointments.where(scheduled_at: last_month_start.beginning_of_day..last_month_end.end_of_day)

    total_customers = current_user_customers.count
    active_customers = current_user_customers.active.count
    retention_rate = total_customers > 0 ? (active_customers.to_f / total_customers * 100).round(1) : 0

    this_month_count = this_month_appointments.count
    last_month_count = last_month_appointments.count

    growth_rate = if last_month_count > 0
      ((this_month_count - last_month_count).to_f / last_month_count * 100).round(1)
    else
      this_month_count > 0 ? 100.0 : 0.0
    end

    this_month_not_cancelled = this_month_appointments.where.not(status: "cancelled")
    reliability_rate = if this_month_not_cancelled.count > 0
      (this_month_not_cancelled.where(status: "completed").count.to_f / this_month_not_cancelled.count * 100).round(1)
    else
      0.0
    end

    trending_up = growth_rate > 0

    {
      retention_rate: retention_rate,
      growth_rate: growth_rate,
      reliability_rate: reliability_rate,
      trending_up: trending_up,
      this_month_appointments: this_month_count,
      last_month_appointments: last_month_count,
      active_customers: active_customers,
      total_customers: total_customers
    }
  end
end
