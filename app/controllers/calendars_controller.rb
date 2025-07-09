require "ostruct"

class CalendarsController < ApplicationController
  before_action :authenticate_user!


  def index
    @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
    @view_mode = params[:view_mode] || "appointments" # Only appointments mode now
    @authorization_unavailable = calendar_data_service.authorization_unavailable?

    @events = calendar_data_service.appointments_for_date(@selected_date)
                                  .map { |apt| calendar_data_service.appointment_to_event_object(apt) }

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("date_navigation", partial: "date_navigation"),
          turbo_stream.update("events_list", partial: "events_list")
        ]
      end
    end
  end

  def redirect
    redirect_to google_calendar_service.authorization_uri, allow_other_host: true
  end

  def callback
    response = google_calendar_service.process_oauth_callback(params[:code])

    # Store in both session (backward compatibility) and user model (new approach)
    session[:authorization] = response
    current_user.update_google_calendar_auth(response) if current_user

    redirect_to calendars_path
  end

  def fullcalendar_events
    # Parse date parameters from FullCalendar
    start_date = params[:start].present? ? Date.parse(params[:start]) : Date.current.beginning_of_month
    end_date = params[:end].present? ? Date.parse(params[:end]) : Date.current.end_of_month

    # Get appointments for the date range
    appointments = current_user_appointments.where(
      scheduled_at: start_date.beginning_of_day..end_date.end_of_day
    ).includes(:customer)

    # Convert to FullCalendar format
    events = appointments.map do |appointment|
      {
        id: appointment.id.to_s,
        title: appointment.customer.name,
        start: appointment.scheduled_at.strftime("%Y-%m-%dT%H:%M:%S"),
        end: (appointment.scheduled_at + appointment.duration.hours).strftime("%Y-%m-%dT%H:%M:%S"),
        backgroundColor: event_background_color(appointment),
        borderColor: event_border_color(appointment),
        textColor: "#ffffff",
        classNames: [
          "appointment-event",
          "status-#{appointment.status}",
          appointment.synced_to_calendar? ? "synced" : "unsynced"
        ],
        extendedProps: {
          customerId: appointment.customer.id,
          customerName: appointment.customer.name,
          customerPhone: appointment.customer.phone,
          status: appointment.status,
          duration: appointment.duration,
          notes: appointment.notes,
          isSynced: appointment.synced_to_calendar?,
          isRecurring: appointment.part_of_recurring_series?,
          creditType: appointment.customer.credit? ? "credit" : "subscription",
          remainingHours: appointment.customer.total_remaining_hours
        }
      }
    end

    render json: events
  end

  # Appointment sync actions
  def sync_appointment
    appointment = current_user_appointment(params[:appointment_id])
    sync_service = GoogleCalendarSyncService.new(current_user)

    if sync_service.sync_appointment(appointment)
      message = "Compromisso sincronizado com Google Calendar!"
    else
      message = "Erro ao sincronizar compromisso."
    end

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
        @events = calendar_data_service.appointments_for_date(@selected_date)
                                      .map { |apt| calendar_data_service.appointment_to_event_object(apt) }
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  rescue ActiveRecord::RecordNotFound
    handle_not_found_error
  rescue Google::Apis::AuthorizationError
    handle_auth_error
  end

  def bulk_sync
    sync_service = GoogleCalendarSyncService.new(current_user)

    if params[:sync_all] == "true"
      # Check if user wants to sync ALL appointments (including completed) or just scheduled
      if params[:include_completed] == "true"
        # Sync ALL unsynced appointments (scheduled + completed + cancelled etc.) as recurring when possible
        synced_count = sync_service.sync_all_appointments_as_recurring
        message = "#{synced_count} compromisso(s) sincronizado(s) com Google Calendar como eventos recorrentes (incluindo concluídos)!"
      else
        # Sync all unsynced scheduled appointments
        if params[:as_recurring] == "true"
          # Sync as recurring events where possible
          synced_count = sync_service.sync_all_scheduled_appointments_as_recurring
          message = "#{synced_count} compromisso(s) sincronizado(s) como eventos recorrentes!"
        else
          # Sync as individual events
          synced_count = sync_service.sync_all_scheduled_appointments
          message = "#{synced_count} compromisso(s) sincronizado(s) com Google Calendar!"
        end
      end
    else
      # Sync appointments for specific date range
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current

      if params[:include_completed] == "true"
        # Sync ALL appointments for period (including completed) as recurring when possible
        synced_count = sync_service.sync_all_appointments_for_period_as_recurring(start_date, end_date)
        message = "#{synced_count} compromisso(s) sincronizado(s) para o período como eventos recorrentes (incluindo concluídos)!"
      else
        if params[:as_recurring] == "true"
          synced_count = sync_service.sync_appointments_for_period_as_recurring(start_date, end_date)
          message = "#{synced_count} compromisso(s) sincronizado(s) como eventos recorrentes para o período!"
        else
          synced_count = sync_service.sync_appointments_for_period(start_date, end_date)
          message = "#{synced_count} compromisso(s) sincronizado(s) para o período!"
        end
      end
    end

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = Date.current
        @events = calendar_data_service.appointments_for_date(@selected_date)
                                      .map { |apt| calendar_data_service.appointment_to_event_object(apt) }
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  rescue Google::Apis::AuthorizationError
    handle_auth_error
  end

  def sync_customer_recurring
    customer = current_user.customers.find(params[:customer_id])
    sync_service = GoogleCalendarSyncService.new(current_user)
    synced_count = sync_service.sync_customer_recurring_appointments(customer)

    message = "#{synced_count} compromisso(s) de #{customer.name} sincronizado(s) como série recorrente!"

    respond_to do |format|
      format.html { redirect_to calendars_path, notice: message }
      format.turbo_stream do
        @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.today
        @events = calendar_data_service.appointments_for_date(@selected_date)
                                      .map { |apt| calendar_data_service.appointment_to_event_object(apt) }
        render turbo_stream: [
          turbo_stream.update("events_list", partial: "events_list"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
    end
  rescue ActiveRecord::RecordNotFound
    handle_not_found_error
  rescue Google::Apis::AuthorizationError
    handle_auth_error
  end

  def daily_completion
    @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @completion_data = appointment_completion_service.get_daily_completion_data(@selected_date)
    @completable_appointments = appointment_completion_service.get_completable_appointments(@selected_date)
    @completed_appointments = current_user_appointments.completed
                                                    .where(completed_at: @selected_date.beginning_of_day..@selected_date.end_of_day)
                                                    .includes(:customer)
                                                    .order(:completed_at)

    # Add daily preview data
    @daily_preview = calendar_metrics_service.calculate_daily_preview(@selected_date)
    @projected_earnings = calendar_metrics_service.calculate_projected_daily_earnings(@selected_date)
  end

  def metrics
    # Get current month data using AppointmentMetricsService
    month = Date.current.month
    year = Date.current.year
    appointment_metrics_service = AppointmentMetricsService.new(current_user, month, year)
    @authorization_unavailable = calendar_data_service.authorization_unavailable?

    @daily_schedule = calendar_metrics_service.calculate_daily_schedule(Date.current)

    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    @weekly_appointments = current_user_appointments.where(
      scheduled_at: week_start.beginning_of_day..week_end.end_of_day,
      status: "scheduled"
    ).includes(:customer)

    # Calculate comprehensive statistics
    @sync_stats = calendar_metrics_service.calculate_sync_statistics

    begin
      @comprehensive_stats = calendar_metrics_service.calculate_comprehensive_stats
      Rails.logger.info "Comprehensive stats calculated: #{@comprehensive_stats}"
    rescue => e
      Rails.logger.error "Error calculating comprehensive stats: #{e.message}"
      @comprehensive_stats = { cancelled: 0, no_show: 0, cancellation_rate: 0, completion_rate: 0 }
    end

    begin
      @monthly_trends = calendar_metrics_service.calculate_monthly_trends
      Rails.logger.info "Monthly trends calculated: #{@monthly_trends.size} months"
    rescue => e
      Rails.logger.error "Error calculating monthly trends: #{e.message}"
      @monthly_trends = []
    end

    begin
      @weekly_performance = calendar_metrics_service.calculate_weekly_performance
      Rails.logger.info "Weekly performance calculated: #{@weekly_performance.size} weeks"
    rescue => e
      Rails.logger.error "Error calculating weekly performance: #{e.message}"
      @weekly_performance = []
    end

    # Build monthly summary using metrics service
    @monthly_summary = {
      earnings: {
        completed: appointment_metrics_service.total_earnings.round(2),
        projected: appointment_metrics_service.projected_earnings.round(2),
        by_customer: appointment_metrics_service.earnings_by_customer.first(10)
      },
      classes: {
        completed: appointment_metrics_service.completed_appointments.count,
        scheduled: appointment_metrics_service.scheduled_appointments.count,
        cancelled: @comprehensive_stats&.dig(:cancelled) || 0,
        no_show: @comprehensive_stats&.dig(:no_show) || 0,
        total: appointment_metrics_service.total_appointments.count,
        forecast: appointment_metrics_service.monthly_forecast
      },
      workload: {
        total_hours: appointment_metrics_service.total_hours.round(1),
        busiest_days: appointment_metrics_service.busiest_days_of_week
      },
      credits: {
        customers_low_credits: appointment_metrics_service.customers_with_low_credits.count,
        consumption_rate: appointment_metrics_service.credit_consumption_rate.round(1)
      },
      sync_status: {
        total_appointments: @sync_stats[:total],
        synced_appointments: @sync_stats[:synced],
        pending_sync: @sync_stats[:unsynced],
        sync_percentage: @sync_stats[:sync_percentage]
      }
    }
  end

      private

  def google_calendar_service
    @google_calendar_service ||= GoogleCalendarService.new(current_user)
  end

  def calendar_metrics_service
    @calendar_metrics_service ||= CalendarMetricsService.new(current_user)
  end

  def calendar_data_service
    @calendar_data_service ||= CalendarDataService.new(current_user)
  end

  def appointment_completion_service
    @appointment_completion_service ||= AppointmentCompletionService.new(current_user)
  end

  def current_user_appointments
    Appointment.joins(:customer).where(customers: { user_id: current_user.id })
  end

  def current_user_appointment(appointment_id)
    current_user_appointments.find(appointment_id)
  end

  def handle_not_found_error
    redirect_to calendars_path, alert: "Compromisso não encontrado."
  end

  def handle_auth_error
    session[:authorization] = nil
    current_user.update_google_calendar_auth(nil) if current_user
    redirect_to calendars_path, alert: "Erro de autorização. Refaça a autenticação."
  end

  # Event styling helpers for FullCalendar
  def event_background_color(appointment)
    case appointment.status
    when "scheduled"
      appointment.customer.credit? ? "#3b82f6" : "#8b5cf6"  # Blue for credit, Purple for subscription
    when "completed"
      "#059669"  # Emerald
    when "cancelled"
      "#ef4444"  # Red
    when "no_show"
      "#f59e0b"  # Amber
    else
      "#6b7280"  # Gray
    end
  end

  def event_border_color(appointment)
    case appointment.status
    when "scheduled"
      appointment.customer.credit? ? "#2563eb" : "#7c3aed"
    when "completed"
      "#047857"
    when "cancelled"
      "#dc2626"
    when "no_show"
      "#d97706"
    else
      "#4b5563"
    end
  end
end
