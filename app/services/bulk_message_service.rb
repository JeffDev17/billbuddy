# Service to handle bulk WhatsApp messaging
class BulkMessageService
  def initialize(user)
    @user = user
  end

  def send_bulk_messages(customers, message, message_type = "custom")
    success_count = 0
    failed_count = 0
    errors = []

    customers.each do |customer|
      begin
        formatted_phone = PhoneFormatterService.format(customer.phone)
        final_message = build_message(customer, message, message_type)

        WhatsappApiService.send_message(formatted_phone, final_message)
        success_count += 1

        # Add a small delay to avoid overwhelming the API
        sleep(0.5)

      rescue => e
        failed_count += 1
        error_msg = "#{customer.name}: #{e.message}"
        errors << error_msg
        Rails.logger.error("Bulk message failed for customer #{customer.id}: #{e.message}")

        # Store failed notification for retry
        FailedNotification.create!(
          customer: customer,
          error_message: e.message,
          notification_type: "bulk_message"
        )
      end
    end

    {
      success_count: success_count,
      failed_count: failed_count,
      errors: errors
    }
  end

  private

  def build_message(customer, custom_message, message_type)
    case message_type
    when "payment_reminder"
      build_payment_reminder_message(customer, custom_message)
    when "general_announcement"
      build_general_announcement(customer, custom_message)
    when "custom"
      build_custom_message(customer, custom_message)
    else
      build_custom_message(customer, custom_message)
    end
  end

  def build_payment_reminder_message(customer, custom_message)
    <<~MESSAGE
      Olá #{customer.name}!

      Este é um lembrete de pagamento importante.

      #{custom_message}

      Para mais informações, entre em contato conosco.

      Att,
      BillBuddy
    MESSAGE
  end

  def build_general_announcement(customer, custom_message)
    <<~MESSAGE
      Olá #{customer.name}!

      #{custom_message}

      Att,
      Equipe BillBuddy
    MESSAGE
  end

  def build_custom_message(customer, custom_message)
    # Replace customer placeholders if any
    message = custom_message.gsub(/\{\{nome\}\}|\{\{name\}\}/, customer.name)

    <<~MESSAGE
      #{message}

      Att,
      BillBuddy
    MESSAGE
  end
end
