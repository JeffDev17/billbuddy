# Service to handle customer notifications (WhatsApp, payment reminders, etc.)
class CustomerNotificationService
  def initialize(customer)
    @customer = customer
  end

  def send_whatsapp_notification
    validate_phone_presence!

    formatted_phone = PhoneFormatterService.format(@customer.phone)
    WhatsappNotificationService.send_low_credit_alert(@customer, formatted_phone)

    success_result("Notificação enviada com sucesso!")
  rescue => e
    failure_result("Erro ao enviar notificação: #{e.message}")
  end

  def send_payment_reminder
    validate_phone_presence!

    formatted_phone = PhoneFormatterService.format(@customer.phone)

    # Build a standard payment reminder message
    message = build_standard_payment_reminder_message

    # Use WhatsappApiService directly to get proper error handling
    WhatsappApiService.send_message(formatted_phone, message)

    success_result("Lembrete de pagamento enviado com sucesso!")
  rescue => e
    error_message = e.message.to_s[0...500] # Limit error message size
    failure_result("Erro ao enviar lembrete de pagamento: #{error_message}")
  end

  def send_custom_payment_reminder(amount, custom_message = nil)
    validate_phone_presence!
    validate_amount!(amount)
    validate_message!(custom_message)

    # Process the fully customizable message with variable substitution
    message = process_custom_message(custom_message, amount)
    formatted_phone = PhoneFormatterService.format(@customer.phone)
    WhatsappApiService.send_message(formatted_phone, message)

    success_result("Mensagem personalizada enviada com sucesso!")
  rescue => e
    error_message = e.message.to_s[0...500] # Limit error message size
    failure_result("Erro ao enviar mensagem: #{error_message}")
  end

  private

  def validate_phone_presence!
    raise StandardError, "Cliente não possui telefone cadastrado" if @customer.phone.blank?
  end

  def validate_amount!(amount)
    raise StandardError, "O valor da cobrança é obrigatório" if amount.blank?
  end

  def validate_message!(message)
    raise StandardError, "A mensagem é obrigatória" if message.blank?
  end

  def build_standard_payment_reminder_message
    <<~MESSAGE
      Olá #{@customer.name}!

      Este é um lembrete de pagamento.

      Por favor, entre em contato conosco para regularizar sua situação.

      Att,
      Equipe BillBuddy
    MESSAGE
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
      Equipe BillBuddy
    MESSAGE

    message
  end

  def process_custom_message(custom_message, amount)
    # Replace variables in the custom message
    formatted_amount = format_amount(amount)

    # Replace {VALOR} with the actual formatted amount
    processed_message = custom_message.gsub(/{VALOR}/i, "R$ #{formatted_amount}")

    processed_message
  end

  def format_amount(amount)
    sprintf("%.2f", amount.to_f).gsub(".", ",")
  end

  def success_result(message)
    { success: true, message: message }
  end

  def failure_result(message)
    { success: false, message: message }
  end
end
