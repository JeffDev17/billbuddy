class WhatsappNotificationService
  def self.send_low_credit_alert(customer, formatted_phone = nil)
    return unless customer.should_notify_low_credits?

    message = build_message(customer)
    phone = formatted_phone || customer.phone
    WhatsappApiService.send_message(phone, message)
  rescue StandardError => e
    handle_error(customer, e)
  end

  private

  def self.build_message(customer)
    <<~MESSAGE
      Olá #{customer.name}!

      Seus créditos estão acabando. Você tem #{customer.total_remaining_hours} horas restantes.

      Para adicionar mais créditos, acesse:
      #{Rails.application.routes.url_helpers.customer_url(customer)}

      Att,
      Equipe BillBuddy
    MESSAGE
  end

  def self.handle_error(customer, error)
    Rails.logger.error("WhatsApp notification failed for customer #{customer.id}: #{error.message}")
    # You might want to store failed notifications for retry
    FailedNotification.create!(
      customer: customer,
      error_message: error.message,
      notification_type: 'low_credits'
    )
  end
end
