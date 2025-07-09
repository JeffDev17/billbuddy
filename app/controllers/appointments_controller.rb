class AppointmentsController < ApplicationController
  include UserScoped

  before_action :authenticate_user!
  before_action :set_appointment, only: [ :edit, :update, :destroy, :mark_completed, :mark_cancelled ]
  before_action :set_customers, only: [ :new, :edit, :bulk_create, :process_bulk_create ]

  # Navigation helper is now available from ApplicationController

  def index
    @appointments = appointment_filter_service.call(params)
    @customers_for_filter = current_user_customers.joins(:appointments).distinct.order(:name)
    @filter_stats = appointment_filter_service.filter_stats
    @current_filters = current_filters_from_params(params)

    store_current_filters(@current_filters)
  end

  def new
    @appointment = Appointment.new(status: "scheduled")

    # Pre-fill from calendar selection if available
    if params[:scheduled_at].present?
      @appointment.scheduled_at = Time.parse(params[:scheduled_at])
    end

    if params[:duration].present?
      @appointment.duration = params[:duration].to_f
    end
  end

  def create
    if recurring_appointment?
      handle_recurring_creation
    else
      handle_single_creation
    end
  end

  def edit
    navigation_service.store_return_path(request.referer, appointments_path)
  end

    def update
    old_status = @appointment.status

    if @appointment.update(appointment_params)
      handle_completion_status_change(old_status)

      respond_to do |format|
        format.html { redirect_to navigation_service.determine_return_path(appointments_path), notice: "Compromisso atualizado com sucesso." }
        format.json do
          render json: {
            success: true,
            message: "Compromisso atualizado com sucesso.",
            appointment: {
              id: @appointment.id,
              title: @appointment.customer.name,
              start: @appointment.scheduled_at.iso8601,
              end: (@appointment.scheduled_at + @appointment.duration.hours).iso8601,
              backgroundColor: event_background_color(@appointment),
              borderColor: event_border_color(@appointment)
            }
          }
        end
        format.turbo_stream do
          @appointments = appointment_filter_service.call(restore_filters_from_session)
          render turbo_stream: [
            turbo_stream.update("appointments-table", partial: "appointments_table"),
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "Compromisso atualizado com sucesso." })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { success: false, errors: @appointment.errors.full_messages } }
      end
    end
  end

  def destroy
    @appointment.destroy

    respond_to do |format|
      format.html { redirect_to navigation_service.determine_return_path(appointments_path), notice: "Compromisso excluído com sucesso." }
      format.turbo_stream do
        @appointments = appointment_filter_service.call(restore_filters_from_session)
        render turbo_stream: [
          turbo_stream.update("appointments-table", partial: "appointments_table"),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "Compromisso excluído com sucesso." })
        ]
      end
    end
  end

  def mark_completed
    completion_date = params[:completion_date].present? ? Date.parse(params[:completion_date]) : @appointment.scheduled_at.to_date
    result = appointment_completion_service.mark_as_completed(@appointment, completion_date)

    if result[:success]
      message = "Compromisso marcado como concluído! Ganhos: R$ #{sprintf('%.2f', result[:earnings])}"
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), notice: message
    else
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), alert: result[:message]
    end
  end

  def mark_cancelled
    if @appointment.update(status: "cancelled")
      message = "Compromisso cancelado com sucesso."
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), notice: message
    else
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), alert: "Erro ao cancelar compromisso."
    end
  end

  def bulk_mark_completed
    appointment_ids = params[:appointment_ids] || []
    completion_date = params[:completion_date].present? ? Date.parse(params[:completion_date]) : Date.current

    result = appointment_bulk_operations_service.bulk_mark_completed(appointment_ids, completion_date)
    return_path = navigation_service.smart_return_path_for_action(request.referer, appointments_path)

    if result[:success]
      redirect_to return_path, notice: result[:message]
    else
      redirect_to return_path, alert: result[:message]
    end
  end

  def bulk_delete_by_customer
    result = appointment_bulk_operations_service.bulk_delete_by_customer(
      params[:customer_id],
      params.permit(:start_date, :end_date, :future_only)
    )

    if result[:success]
      redirect_to appointments_path, notice: result[:message]
    else
      redirect_to appointments_path, alert: result[:message]
    end
  end

  def bulk_create
    setup_bulk_create_defaults
  end

  def process_bulk_create
    result = appointment_bulk_operations_service.process_bulk_create(
      selected_customers,
      Date.parse(params[:start_date]),
      Date.parse(params[:end_date]),
      recurring_days,
      time_slots,
      params[:duration].to_f
    )

    if result[:success]
      redirect_to appointments_path, notice: result[:message]
    else
      setup_bulk_create_defaults
      flash.now[:alert] = result[:message]
      render :bulk_create
    end
  end

  def sync_all_appointments
    result = appointment_sync_operations_service.sync_all_appointments

    if result[:success]
      redirect_back(fallback_location: appointments_path, notice: result[:message])
    else
      redirect_back(fallback_location: appointments_path, alert: result[:message])
    end
  end

  def sync_upcoming_appointments
    weeks_ahead = params[:weeks_ahead]&.to_i || 4
    result = appointment_sync_operations_service.sync_upcoming_appointments(weeks_ahead)

    if result[:success]
      redirect_back(fallback_location: appointments_path, notice: result[:message])
    else
      redirect_back(fallback_location: appointments_path, alert: result[:message])
    end
  end

  def review_sync
    @sync_scope = params[:scope] || "upcoming"
    @weeks_ahead = params[:weeks_ahead]&.to_i || 4
    @customer_id = params[:customer_id]
    @customer_ids = params[:customer_ids] || []

    @appointments = appointment_sync_operations_service.prepare_sync_review(
      @sync_scope, @weeks_ahead, @customer_id, @customer_ids
    )

    case @sync_scope
    when "customer", "customer_upcoming"
      @customer = find_customer(@customer_id)
    when "selected_customers", "selected_customers_all"
      @customers = current_user_customers.where(id: @customer_ids)
    end

    @sync_stats = appointment_sync_operations_service.calculate_sync_stats(@appointments)
  end

  def confirm_sync
    scope = params[:scope]
    weeks_ahead = params[:weeks_ahead]&.to_i || 4
    customer_id = params[:customer_id]
    customer_ids = params[:customer_ids] || []

    result = appointment_sync_operations_service.confirm_sync(scope, weeks_ahead, customer_id, customer_ids)

    if result[:success]
      redirect_to appointments_path, notice: result[:message]
    else
      redirect_to appointments_path, alert: result[:message]
    end
  end

  def manage_auto_generation
    @next_scheduled_run = MonthlyAppointmentScheduler.next_scheduled_run
    @has_scheduled_job = @next_scheduled_run.present?
  end

  def setup_auto_generation
    MonthlyAppointmentScheduler.setup_recurring_schedule
    redirect_to manage_auto_generation_appointments_path,
                notice: "Geração automática de compromissos configurada com sucesso!"
  end

  def cancel_auto_generation
    cancelled_count = MonthlyAppointmentScheduler.cancel_scheduled_jobs
    redirect_to manage_auto_generation_appointments_path,
                notice: "#{cancelled_count} agendamentos de geração automática cancelados."
  end

  def run_auto_generation_now
    MonthlyAppointmentScheduler.run_now_for_testing
    redirect_to manage_auto_generation_appointments_path,
                notice: "Geração automática executada imediatamente. Verifique os logs para detalhes."
  end

  def preview_generation
    target_month = params[:target_month].to_i
    target_year = params[:target_year].to_i

    if target_month.between?(1, 12) && target_year > 2020
      @preview_data = MonthlyAppointmentScheduler.preview_generation_for_month(target_month, target_year)
      @target_month = target_month
      @target_year = target_year
    else
      redirect_to manage_auto_generation_appointments_path,
                  alert: "Mês/ano inválido."
    end
  end

  def confirm_generation
    target_month = params[:target_month].to_i
    target_year = params[:target_year].to_i

    if target_month.between?(1, 12) && target_year > 2020
      result = MonthlyAppointmentScheduler.run_for_specific_month(target_month, target_year)
      redirect_to manage_auto_generation_appointments_path,
                  notice: "#{result[:created]} compromissos criados para #{target_month}/#{target_year}."
    else
      redirect_to manage_auto_generation_appointments_path,
                  alert: "Mês/ano inválido."
    end
  end

  private

  def set_appointment
    @appointment = find_customer_appointment(params[:id])
  end

  def set_customers
    @customers = current_user_customers.active.order(:name)
  end

  def appointment_params
    params.require(:appointment).permit(:customer_id, :scheduled_at, :duration, :status, :notes)
  end

  def appointment_filter_service
    @appointment_filter_service ||= AppointmentFilterService.new(current_user)
  end

  def appointment_creation_service
    @appointment_creation_service ||= AppointmentCreationService.new(current_user)
  end

  def appointment_completion_service
    @appointment_completion_service ||= AppointmentCompletionService.new(current_user)
  end

  def manual_sync_service
    @manual_sync_service ||= ManualCalendarSyncService.new(current_user)
  end

  def appointment_bulk_operations_service
    @appointment_bulk_operations_service ||= AppointmentBulkOperationsService.new(current_user)
  end

  def appointment_sync_operations_service
    @appointment_sync_operations_service ||= AppointmentSyncOperationsService.new(current_user)
  end

  def current_filters_from_params(params)
    {
      search: params[:search],
      customer_id: params[:customer_id],
      status: params[:status],
      start_date: params[:start_date],
      end_date: params[:end_date],
      sync_status: params[:sync_status]
    }.compact
  end



  def recurring_appointment?
    params[:is_recurring] == "1" && params[:recurring_days].present?
  end

  def handle_recurring_creation
    recurring_params = {
      days: params[:recurring_days],
      until: params[:recurring_until],
      no_end_date: params[:no_end_date]
    }

    # Don't sync recurring appointments to calendar by default
    result = appointment_creation_service.create_recurring(appointment_params, recurring_params, sync_to_calendar: false)

    if result[:success]
      message = build_success_message(result[:appointments].count)
      redirect_to appointments_path, notice: message
    else
      @appointment = Appointment.new(appointment_params.merge(status: "scheduled"))
      render :new
    end
  end

  def handle_single_creation
    result = appointment_creation_service.create_single(appointment_params)

    if result[:success]
      appointment = result[:appointment]
      message = "Compromisso criado com sucesso."
      message += " Use os botões de sincronização para enviar ao Google Calendar." if current_user.google_calendar_authorized?

      respond_to do |format|
        format.html { redirect_to appointments_path, notice: message }
        format.json do
          render json: {
            success: true,
            message: message,
            appointment: {
              id: appointment.id,
              title: appointment.customer.name,
              start: appointment.scheduled_at.iso8601,
              end: (appointment.scheduled_at + appointment.duration.hours).iso8601,
              backgroundColor: event_background_color(appointment),
              borderColor: event_border_color(appointment)
            }
          }
        end
      end
    else
      @appointment = result[:appointment] || Appointment.new(appointment_params.merge(status: "scheduled"))

      respond_to do |format|
        format.html { render :new }
        format.json { render json: { success: false, errors: @appointment.errors.full_messages } }
      end
    end
  end

  def handle_completion_status_change(old_status)
  end

  def date_range_provided?
    params[:start_date].present? && params[:end_date].present?
  end

  def setup_bulk_create_defaults
    @start_date = Date.current.next_week(:monday)
    @end_date = @start_date + 4.weeks - 1.day
    @default_duration = 1.0
    @default_times = [ "09:00", "14:00", "19:00" ]
  end

  def selected_customers
    current_user_customers.where(id: params[:customer_ids])
  end

  def recurring_days
    params[:recurring_days]&.map(&:to_i) || []
  end

  def time_slots
    params[:time_slots]&.reject(&:blank?) || []
  end

  def redirect_with_error(message)
    redirect_to bulk_create_appointments_path, alert: message
  end

  def build_success_message(count)
    message = "#{count} compromissos recorrentes criados com sucesso."
    message += " Use os botões de sincronização para enviar ao Google Calendar." if current_user.google_calendar_authorized?
    message
  end

  # Event styling helpers for FullCalendar (shared with CalendarsController)
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
