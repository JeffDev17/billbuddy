class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Basic stats
    @customers_count = current_user_customers.count
    @active_customers = current_user_customers.active.count
    @total_appointments_today = current_user_appointments.today.count
    @completed_appointments_today = current_user_appointments.today.completed.count

    # Today's agenda and completion data
    @selected_date = Date.current
    @daily_completion_data = appointment_completion_service.get_daily_completion_data(@selected_date)
    @todays_appointments = appointment_completion_service.get_completable_appointments(@selected_date)

    # Weekly metrics
    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    @weekly_stats = calculate_weekly_stats(week_start, week_end)

    # Upcoming appointments (next 5)
    @upcoming_appointments = current_user_appointments
                              .where("scheduled_at > ?", Time.current)
                              .includes(:customer)
                              .order(:scheduled_at)
                              .limit(5)

    # Recent activity (last 5 completed)
    @recent_completed = current_user_appointments
                        .completed
                        .includes(:customer)
                        .order(completed_at: :desc)
                        .limit(5)

    # Revenue insights
    @insights = calculate_revenue_insights

    # Low credit warnings
    @low_credit_customers = current_user_customers
                            .credit
                            .joins(:customer_credits)
                            .where("customer_credits.remaining_hours <= ?", 2)
                            .distinct
                            .limit(5)
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

    {
      total: appointments.count,
      completed: appointments.completed.count,
      scheduled: appointments.scheduled.count,
      cancelled: appointments.cancelled.count,
      total_hours: appointments.sum(:duration),
      completion_rate: appointments.count > 0 ?
        (appointments.completed.count.to_f / appointments.count * 100).round(1) : 0
    }
  end

    def calculate_revenue_insights
    # Calculate today's earnings
    todays_earnings = calculate_earnings_for_period(Date.current.beginning_of_day..Date.current.end_of_day)

    # Calculate this week's earnings
    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    weekly_earnings = calculate_earnings_for_period(week_start.beginning_of_day..week_end.end_of_day)

    # Calculate average hourly rate across all customers
    avg_hourly_rate = calculate_average_hourly_rate

    # Find best earning day this week
    best_day_this_week = find_best_earning_day_this_week(week_start, week_end)

    # Calculate pending payments amount
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
      next if date > Date.current # Don't calculate future days

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
end
