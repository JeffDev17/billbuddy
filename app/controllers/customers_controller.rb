class CustomersController < ApplicationController
  include UserScoped

  before_action :authenticate_user!
  before_action :set_customer, only: [ :show, :edit, :update, :destroy, :debit_hours, :notify_whatsapp,
                                      :notify_payment_reminder, :payment_reminder_form, :send_payment_reminder,
                                      :sync_appointments, :sync_upcoming_appointments ]

  def index
    @customers = current_user_customers
    @customers = @customers.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @customers = @customers.where(status: params[:status]) if params[:status].present?
    @customers = @customers.where(plan_type: params[:plan_type]) if params[:plan_type].present?

    # Group customers by status
    @active_customers = @customers.active
    @inactive_customers = @customers.inactive
    @on_hold_customers = @customers.on_hold

    # Ordenar por nome
    @customers = @customers.order(:name)
    @active_customers = @active_customers.order(:name)
    @inactive_customers = @inactive_customers.order(:name)
    @on_hold_customers = @on_hold_customers.order(:name)

    # Para o mapa de calendário
    @customers_with_phone = current_user_customers.where.not(phone: [ nil, "" ])
  end

  def show
    @active_credits = @customer.customer_credits.where("remaining_hours > 0").order(purchase_date: :desc)
    @total_remaining_hours = @active_credits.sum(:remaining_hours)
    @active_subscription = @customer.active_subscription

    # Get all appointments with proper ordering and grouping
    @all_appointments = @customer.appointments.includes(:customer).order(scheduled_at: :desc)
    @appointments_by_status = @all_appointments.group_by(&:status)

    # Separate past appointments from future ones for accurate completion rate calculation
    current_time = Time.current
    past_appointments = @all_appointments.select { |apt| apt.scheduled_at <= current_time }
    future_appointments = @all_appointments.select { |apt| apt.scheduled_at > current_time }

    # Group past appointments by status for accurate rate calculations
    past_appointments_by_status = past_appointments.group_by(&:status)

    # Calculate completion stats based on past appointments only
    past_completed = past_appointments_by_status["completed"]&.count || 0
    past_cancelled = past_appointments_by_status["cancelled"]&.count || 0
    past_no_show = past_appointments_by_status["no_show"]&.count || 0
    past_total = past_completed + past_cancelled + past_no_show

    # Quick stats for appointments
    @appointment_stats = {
      total: @all_appointments.count,
      scheduled: @appointments_by_status["scheduled"]&.count || 0,
      completed: @appointments_by_status["completed"]&.count || 0,
      cancelled: @appointments_by_status["cancelled"]&.count || 0,
      no_show: @appointments_by_status["no_show"]&.count || 0,
      # Add stats for accurate rate calculations
      past_total: past_total,
      past_completed: past_completed,
      past_cancelled: past_cancelled,
      past_no_show: past_no_show,
      future_scheduled: future_appointments.count
    }

    @extra_time_balances = @customer.extra_time_balances.valid
    @active_credit = @customer.active_credit
    @recent_payments = @customer.payments.order(payment_date: :desc).limit(5)
    @earnings_this_month = @customer.earnings_for_month(Date.current.month, Date.current.year)
    @payments_this_month = @customer.payments_for_month(Date.current.month, Date.current.year)
  end

  def new
    @customer = current_user_customers.new
  end

  def create
    @customer = current_user_customers.new(customer_params)

        if @customer.save
      redirect_to @customer, notice: "Cliente criado com sucesso."
        else
      render :new
        end
  end

  def edit
  end

  def update
    # Check if status is changing to inactive and handle cancellation tracking
    if customer_params[:status] == "inactive" && @customer.active?
      handle_customer_cancellation
    elsif customer_params[:status] == "active" && !@customer.active?
      handle_customer_reactivation
    end

    if @customer.update(customer_params)
      redirect_to @customer, notice: "Cliente atualizado com sucesso."
    else
      render :edit
    end
  end

  def destroy
    # Log the deletion for audit purposes
    Rails.logger.info "Customer deleted: #{@customer.name} (#{@customer.id}) by #{current_user.email}"

    @customer.destroy
    redirect_to customers_url, notice: "Cliente excluído com sucesso."
  end

  def debit_hours
    hours_to_debit = params[:hours].to_f
    reason = params[:reason]

    if hours_to_debit <= 0
      redirect_to @customer, alert: "O número de horas deve ser maior que zero."
      return
    end

    if @customer.deduct_credits(hours_to_debit, reason)
      redirect_to @customer, notice: "#{hours_to_debit} horas foram debitadas com sucesso."
    else
      redirect_to @customer, alert: "O cliente não possui horas suficientes."
    end
  end

  def notify_whatsapp
    result = customer_notification_service.send_whatsapp_notification

    if result[:success]
      redirect_to @customer, notice: result[:message]
    else
      redirect_to @customer, alert: result[:message]
    end
  end

  def notify_payment_reminder
    result = customer_notification_service.send_payment_reminder

    if result[:success]
      redirect_to @customer, notice: result[:message]
    else
      redirect_to @customer, alert: result[:message]
    end
  end

  def payment_reminder_form
    # Renders the payment reminder form
  end

  def send_payment_reminder
    begin
      result = payment_reminder_service.send_reminder(@customer)

      if result[:success]
        redirect_to @customer, notice: result[:message]
      else
        redirect_to @customer, alert: result[:message]
      end
    rescue => e
      Rails.logger.error "Payment reminder error: #{e.message}"
      redirect_to @customer, alert: "Erro ao enviar lembrete de pagamento."
    end
  end

  def bulk_message_form
    @target_audience = params[:target_audience] || "all"
    @selected_customer_ids = params[:selected_customer_ids] || []

    @customers_with_phone = filter_customers_by_audience(@target_audience, @selected_customer_ids)
  end

  def send_bulk_message
    @target_audience = params[:target_audience]
    @selected_customer_ids = params[:selected_customer_ids] || []
    @customers_with_phone = filter_customers_by_audience(@target_audience, @selected_customer_ids)

    result = bulk_message_service.send_bulk_message(
      customers: @customers_with_phone,
      message: params[:message],
      target_audience: @target_audience
    )

    if result[:success]
      redirect_to customers_path, notice: result[:message]
    else
      flash.now[:alert] = result[:message]
      render :bulk_message_form
    end
  end

  def import_csv
    # Show the import form
  end

  def process_csv_import
    unless params[:csv_file].present?
      redirect_to import_csv_customers_path, alert: "Por favor, selecione um arquivo CSV."
      return
    end

    begin
      results = Customer.import_from_csv(params[:csv_file], current_user)

      if results[:errors].any?
        flash[:alert] = "Importação concluída com alguns erros. #{results[:success]} clientes importados, #{results[:errors].count} erros."
        @import_errors = results[:errors]
        render :import_csv
      else
        redirect_to customers_path, notice: "#{results[:success]} clientes importados com sucesso!"
      end
    rescue => e
      redirect_to import_csv_customers_path, alert: "Erro ao processar o arquivo: #{e.message}"
    end
  end

  def export_csv
    respond_to do |format|
      format.csv do
        send_data Customer.to_csv(current_user_customers),
                  filename: "clientes_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: "text/csv; charset=utf-8; header=present"
      end
    end
  end

  def download_template
    respond_to do |format|
      format.csv do
        send_data Customer.csv_template,
                  filename: "template_clientes.csv",
                  type: "text/csv; charset=utf-8; header=present"
      end
    end
  end

  def sync_appointments
    result = manual_sync_service.sync_customer_appointments(@customer)

    if result[:success]
      redirect_back(fallback_location: @customer,
                    notice: "#{result[:synced]} compromissos de #{@customer.name} sincronizados com o Google Calendar.")
    else
      redirect_back(fallback_location: @customer,
                    alert: result[:error] || "Erro ao sincronizar compromissos.")
    end
  end

    def sync_upcoming_appointments
    weeks_ahead = params[:weeks_ahead]&.to_i || 4  # Changed from 2 to 4 weeks (1 month)
    result = manual_sync_service.sync_customer_upcoming_appointments(@customer, weeks_ahead: weeks_ahead)

    if result[:success]
      redirect_back(fallback_location: @customer,
                    notice: "#{result[:synced]} compromissos futuros de #{@customer.name} sincronizados.")
    else
      redirect_back(fallback_location: @customer,
                    alert: result[:error] || "Erro ao sincronizar compromissos futuros.")
    end
  end

  private

  def set_customer
    @customer = find_customer(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :status, :plan_type, :custom_hourly_rate, :package_value, :package_hours, :cancellation_reason)
  end

  def customer_notification_service
    @customer_notification_service ||= CustomerNotificationService.new(@customer)
  end

  def manual_sync_service
    @manual_sync_service ||= ManualCalendarSyncService.new(current_user)
  end

  def bulk_message_service
    @bulk_message_service ||= BulkMessageService.new(current_user)
  end

  def payment_reminder_service
    @payment_reminder_service ||= PaymentReminderService.new(current_user)
  end

  def filter_customers_by_audience(target_audience, selected_customer_ids = nil)
    case target_audience
    when "all"
      current_user_customers.where.not(phone: [ nil, "" ])
    when "active"
      current_user_customers.active.where.not(phone: [ nil, "" ])
    when "credit"
      current_user_customers.credit.where.not(phone: [ nil, "" ])
    when "subscription"
      current_user_customers.subscription.where.not(phone: [ nil, "" ])
    when "specific"
      if selected_customer_ids.present?
        current_user_customers.where(id: selected_customer_ids).where.not(phone: [ nil, "" ])
      else
        current_user_customers.none
      end
    else
      current_user_customers.where.not(phone: [ nil, "" ])
    end
  end

  def handle_customer_cancellation
    # Set cancellation tracking
    @customer.cancelled_at = Time.current
    @customer.cancelled_by = current_user.email

    # You could add a cancellation reason form field if needed
    @customer.cancellation_reason = params.dig(:customer, :cancellation_reason) || "Status changed to inactive"

    # Log the cancellation
    Rails.logger.info "Customer cancelled: #{@customer.name} (#{@customer.id}) by #{current_user.email} - Reason: #{@customer.cancellation_reason}"
  end

  def handle_customer_reactivation
    # Clear cancellation tracking and set new activation date
    @customer.cancelled_at = nil
    @customer.cancelled_by = nil
    @customer.cancellation_reason = nil
    @customer.activated_at = Time.current

    # Log the reactivation
    Rails.logger.info "Customer reactivated: #{@customer.name} (#{@customer.id}) by #{current_user.email}"
  end
end
