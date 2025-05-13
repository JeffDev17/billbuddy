class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: [:show, :edit, :update, :destroy, :debit_hours, :payment_reminder_form, :send_payment_reminder]

  def index
    @customers = current_user.customers.order(name: :asc)
  end

  def show
    @active_credits = @customer.customer_credits.where('remaining_hours > 0').order(purchase_date: :desc)
    @total_remaining_hours = @active_credits.sum(:remaining_hours)
    @active_subscription = @customer.active_subscription
    @upcoming_appointments = @customer.appointments.where('scheduled_at > ?', Time.current).order(scheduled_at: :asc).limit(5)
    @extra_time_balances = @customer.extra_time_balances.valid
  end

  def new
    @customer = current_user.customers.new
  end

  def create
    @customer = current_user.customers.new(customer_params)

    if @customer.save
      redirect_to @customer, notice: 'Cliente criado com sucesso.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: 'Cliente atualizado com sucesso.'
    else
      render :edit
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: 'Cliente excluído com sucesso.'
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
    @customer = current_user.customers.find(params[:id])
  
    if @customer.phone.blank?
      redirect_to @customer, alert: "Cliente não possui telefone cadastrado."
      return
    end
  
    begin
      formatted_phone = format_phone_number(@customer.phone)
      WhatsappNotificationService.send_low_credit_alert(@customer, formatted_phone)
      redirect_to @customer, notice: "Notificação enviada com sucesso!"
    rescue StandardError => e
      redirect_to @customer, alert: "Erro ao enviar notificação: #{e.message}"
    end
  end
  
  def notify_payment_reminder
    @customer = current_user.customers.find(params[:id])
  
    if @customer.phone.blank?
      redirect_to @customer, alert: "Cliente não possui telefone cadastrado."
      return
    end
  
    begin
      formatted_phone = format_phone_number(@customer.phone)
      PaymentReminderService.send_payment_reminder(@customer, formatted_phone)
      redirect_to @customer, notice: "Lembrete de pagamento enviado com sucesso!"
    rescue StandardError => e
      error_message = e.message.to_s[0...500] # Limit error message size
      redirect_to @customer, alert: "Erro ao enviar lembrete de pagamento: #{error_message}"
    end
  end

  def payment_reminder_form
    # Esta action vai renderizar o formulário de cobrança
  end

  def send_payment_reminder
    amount = params[:amount]
    custom_message = params[:message]

    if amount.blank?
      redirect_to @customer, alert: "O valor da cobrança é obrigatório."
      return
    end

    begin
      message = build_payment_reminder_message(amount, custom_message)
      formatted_phone = format_phone_number(@customer.phone)
      WhatsappApiService.send_message(formatted_phone, message)
      redirect_to @customer, notice: "Mensagem de cobrança enviada com sucesso!"
    rescue StandardError => e
      error_message = e.message.to_s[0...500] # Limit error message size
      redirect_to @customer, alert: "Erro ao enviar mensagem: #{error_message}"
    end
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :status, :plan_type)
  end

  def format_phone_number(phone)
    # Remove caracteres não numéricos, mantendo o +
    numbers_only = phone.gsub(/[^\d+]/, '')
    
    # Garante que começa com +
    numbers_only.start_with?('+') ? numbers_only : "+#{numbers_only}"
  end

  def build_payment_reminder_message(amount, custom_message = nil)
    message = <<~MESSAGE
      Olá #{@customer.name}!

      Este é um lembrete de pagamento no valor de R$ #{format_amount(amount)}.
    MESSAGE

    if custom_message.present?
      message += "\n#{custom_message}\n"
    end

    message += <<~MESSAGE

      Para mais informações ou realizar o pagamento, entre em contato conosco.

      Att,
      BillBuddy
    MESSAGE

    message
  end

  def format_amount(amount)
    sprintf('%.2f', amount.to_f)
  end

end