class AppointmentsController < ApplicationController
  include UserScoped

  before_action :authenticate_user!
  before_action :set_appointment, only: [ :edit, :update, :destroy, :mark_completed, :mark_cancelled, :cancellation_options, :reschedule ]
  before_action :set_customers, only: [ :new, :create, :edit, :update ]

  def index
    # Default to current week if no date filters are provided (for better performance)
    if params[:start_date].blank? && params[:end_date].blank? && params[:month].blank? && params[:year].blank?
      params[:start_date] = Date.current.beginning_of_week.strftime("%Y-%m-%d")
      params[:end_date] = Date.current.end_of_week.strftime("%Y-%m-%d")
    end

    @appointments = appointment_filter_service.call(params)
    @customers_for_filter = current_user_customers.joins(:appointments).distinct.order(:name)
    @filter_stats = appointment_filter_service.filter_stats
    @current_filters = current_filters_from_params(params)

    store_current_filters(@current_filters)
  end

  def new
    @appointment = Appointment.new(status: "scheduled")
    @appointment.scheduled_at = Time.parse(params[:scheduled_at]) if params[:scheduled_at].present?
    @appointment.duration = params[:duration].to_f if params[:duration].present?
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
    if @appointment.update(appointment_params)
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
  def cancellation_options
    @cancellation_options = appointment_cancellation_service.get_cancellation_options(@appointment)
    render partial: "cancellation_options_modal", locals: { appointment: @appointment, options: @cancellation_options }
  end

  def mark_cancelled
    result = appointment_cancellation_service.cancel_appointment(
      @appointment,
      {
        reason: params[:cancellation_reason],
        force_type: params[:cancellation_type]
      }
    )

    if result[:success]
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), notice: result[:message]
    else
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), alert: result[:message]
    end
  end

  def reschedule
    new_datetime = Time.parse("#{params[:reschedule_date]} #{params[:reschedule_time]}")
    new_duration = params[:new_duration].present? ? params[:new_duration].to_f : nil

    result = appointment_cancellation_service.reschedule_appointment(@appointment, new_datetime, new_duration)

    if result[:success]
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), notice: result[:message]
    else
      redirect_to navigation_service.smart_return_path_for_action(request.referer, appointments_path), alert: result[:message]
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
    # Simple fast loading - no need to check scheduled jobs for basic view
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

  def fill_current_month
    start_date = Date.current
    end_date = Date.current.end_of_month

    if params[:customer_id].present?
      customer = current_user.customers.find(params[:customer_id])
      generator = ScheduleBasedAppointmentGenerator.new(current_user)
      result = generator.generate_for_customer(customer, start_date, end_date)
      message = "#{result[:created]} compromissos criados para #{customer.name} no mês atual"
      message += ". Erros: #{result[:errors].count}" if result[:errors].any?
    else
      generator = ScheduleBasedAppointmentGenerator.new(current_user)
      result = generator.generate_appointments(start_date, end_date)
      message = "#{result[:appointments_created]} compromissos criados para preencher lacunas do mês atual usando horários regulares"
      message += ". #{result[:customers_processed]} clientes processados"
      message += ". Erros: #{result[:errors].count}" if result[:errors].any?
    end

    redirect_to manage_auto_generation_appointments_path, notice: message
  end

  def generate_next_month
    if params[:customer_id].present?
      customer = current_user.customers.find(params[:customer_id])
      generator = ScheduleBasedAppointmentGenerator.new(current_user)
      start_date = Date.current.next_month.beginning_of_month
      end_date = Date.current.next_month.end_of_month
      result = generator.generate_for_customer(customer, start_date, end_date)
      message = "#{result[:created]} compromissos criados para #{customer.name} em #{Date.current.next_month.strftime('%B de %Y')}"
      message += ". Erros: #{result[:errors].count}" if result[:errors].any?
    else
      generator = ScheduleBasedAppointmentGenerator.new(current_user)
      result = generator.generate_next_month
      message = "#{result[:appointments_created]} compromissos criados com base em horários regulares para #{Date.current.next_month.strftime('%B de %Y')}"
      message += ". #{result[:customers_processed]} clientes processados"
      message += ". Erros: #{result[:errors].count}" if result[:errors].any?
    end

    redirect_path = params[:from_preview] == "true" ? preview_next_month_appointments_path : manage_auto_generation_appointments_path
    redirect_to redirect_path, notice: message
  end
  def preview_next_month
    start_date = Date.current.next_month.beginning_of_month
    end_date = Date.current.next_month.end_of_month


    generator = ScheduleBasedAppointmentGenerator.new(current_user)
    @preview_result = generator.generate_appointments(start_date, end_date, preview_only: true)
    @generation_type = "schedule_based"

    @target_month = Date.current.next_month.strftime("%B de %Y")
  end
  def preview_current_month
    start_date = Date.current
    end_date = Date.current.end_of_month

    # Always use schedule-based generation (simplified)
    generator = ScheduleBasedAppointmentGenerator.new(current_user)
    @preview_result = generator.generate_appointments(start_date, end_date, preview_only: true)
    @generation_type = "schedule_based"
    @is_current_month = true

    @target_month = Date.current.strftime("%B de %Y")
    render :preview_next_month
  end

  def generate_custom_period
    start_date = Date.parse(params[:start_date])
    end_date = Date.parse(params[:end_date])

    generator = ScheduleBasedAppointmentGenerator.new(current_user)

    if params[:preview]
      @preview_result = generator.generate_appointments(start_date, end_date, preview_only: true)
      @generation_type = "schedule_based"
      @target_period = "#{start_date.strftime('%d/%m/%Y')} a #{end_date.strftime('%d/%m/%Y')}"
      render :preview_custom_period
    else
      result = generator.generate_appointments(start_date, end_date)

      message = "#{result[:appointments_created]} compromissos criados para o período #{start_date.strftime('%d/%m/%Y')} - #{end_date.strftime('%d/%m/%Y')} usando horários regulares"
      message += ". #{result[:customers_processed]} clientes processados"
      message += ". Erros: #{result[:errors].count}" if result[:errors].any?

      redirect_to manage_auto_generation_appointments_path, notice: message
    end
  rescue Date::Error
    redirect_to manage_auto_generation_appointments_path, alert: "Datas inválidas fornecidas"
  end
  def get_month_stats
    year = params[:year].to_i
    month = params[:month].to_i

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    appointments = Appointment.joins(:customer).where(customers: { user_id: current_user.id }).where(scheduled_at: start_date..end_date)

    by_status = appointments.group(:status).count

    stats = {
      month: month,
      year: year,
      month_name: start_date.strftime("%B de %Y"),
      total_appointments: appointments.count,
      total_customers: appointments.select(:customer_id).distinct.count,
      total_hours: appointments.sum(:duration),
      by_status: by_status,
      is_future: Date.new(year, month, 1) > Date.current
    }

    render json: stats
  rescue => e
    render json: { error: "Erro ao obter estatísticas: #{e.message}" }, status: 400
  end

  def delete_month_appointments
    year = params[:year].to_i
    month = params[:month].to_i

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    appointments = Appointment.joins(:customer).where(customers: { user_id: current_user.id }).where(scheduled_at: start_date..end_date).where("scheduled_at > ?", Time.current)
    deleted_count = appointments.count
    appointments.destroy_all
    month_name = start_date.strftime("%B de %Y")
    redirect_to manage_auto_generation_appointments_path, notice: "#{deleted_count} compromissos futuros deletados de #{month_name}"
  rescue => e
    redirect_to manage_auto_generation_appointments_path, alert: "Erro ao deletar compromissos: #{e.message}"
  end

  def generate_specific_month
    year = params[:year].to_i
    month = params[:month].to_i

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    generator = ScheduleBasedAppointmentGenerator.new(current_user)
    result = generator.generate_appointments(start_date, end_date)

    month_name = start_date.strftime("%B de %Y")
    message = "#{result[:appointments_created]} compromissos criados para #{month_name} usando horários regulares"
    message += ". #{result[:customers_processed]} clientes processados"
    message += ". Erros: #{result[:errors].count}" if result[:errors].any?

    redirect_to manage_auto_generation_appointments_path, notice: message
  rescue => e
    redirect_to manage_auto_generation_appointments_path, alert: "Erro ao gerar compromissos: #{e.message}"
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
    @customers = current_user_customers.where(status: "active").order(:name)
  end

  def appointment_params
    params.require(:appointment).permit(
      :customer_id, :scheduled_at, :duration, :status, :notes,
      :cancellation_type, :cancellation_reason, :cancelled_at,
      :hourly_rate
    )
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

  def appointment_bulk_operations_service
    @appointment_bulk_operations_service ||= AppointmentBulkOperationsService.new(current_user)
  end

  def appointment_sync_operations_service
    @appointment_sync_operations_service ||= AppointmentSyncOperationsService.new(current_user)
  end

  def appointment_cancellation_service
    @appointment_cancellation_service ||= AppointmentCancellationService.new(current_user)
  end

  def current_filters_from_params(params)
    {
      search: params[:search],
      customer_id: params[:customer_id],
      status: params[:status],
      start_date: params[:start_date],
      end_date: params[:end_date],
      sync_status: params[:sync_status],
      sort_order: params[:sort_order],
      month: params[:month],
      year: params[:year]
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
      flash.now[:alert] = "Erro ao criar compromisso: #{@appointment.errors.full_messages.join(', ')}"

      respond_to do |format|
        format.html { render :new }
        format.json { render json: { success: false, errors: @appointment.errors.full_messages } }
      end
    end
  end

  def build_success_message(count)
    message = "#{count} compromissos recorrentes criados com sucesso."
    message += " Use os botões de sincronização para enviar ao Google Calendar." if current_user.google_calendar_authorized?
    message
  end
end
