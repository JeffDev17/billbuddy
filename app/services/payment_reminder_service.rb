class PaymentReminderService
  def self.send_payment_reminder(customer, formatted_phone = nil)
    return unless customer.phone.present?

    message = build_message(customer)
    phone = formatted_phone || customer.phone
    WhatsappApiService.send_message(phone, message)
  rescue StandardError => e
    handle_error(customer, e)
  end

  def self.send_bulk_payment_reminders(days_overdue = 7)
    # Find customers with active subscriptions that are overdue
    overdue_customers = find_overdue_customers(days_overdue)
    
    results = { success: [], failed: [] }
    
    overdue_customers.each do |customer|
      begin
        send_payment_reminder(customer)
        results[:success] << customer.id
      rescue => e
        results[:failed] << { id: customer.id, error: e.message }
      end
    end
    
    results
  end

  private

  def self.find_overdue_customers(days_overdue)
    # This is a placeholder implementation
    # You'll need to implement the actual logic to find customers with overdue payments
    # based on your subscription and payment models
    Customer.joins(:subscriptions)
           .where(subscriptions: { status: 'active' })
           .where("DATE(NOW()) - INTERVAL '? days' >= subscriptions.billing_day", days_overdue)
           .distinct
  end

  def self.build_message(customer)
    <<~MESSAGE
      Olá #{customer.name}!

      Notamos que você possui um pagamento pendente. 
      Por favor, entre em contato conosco para regularizar sua situação.

      Att,
      Equipe BillBuddy
    MESSAGE
  end

  def self.handle_error(customer, error)
    Rails.logger.error("WhatsApp payment reminder failed for customer #{customer.id}: #{error.message}")
    # Store failed notifications for retry
    FailedNotification.create!(
      customer: customer,
      error_message: error.message,
      notification_type: 'payment_reminder'
    )
  end
end