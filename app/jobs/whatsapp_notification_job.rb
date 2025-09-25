class WhatsappNotificationJob < ApplicationJob
  queue_as :default
  # Skip WhatsApp-specific error handling if WahaService is not available
  if defined?(WahaService)
    retry_on WahaService::WahaError, wait: :exponentially_longer, attempts: 3
  end

  def perform(customer_id)
    customer = Customer.find(customer_id)
    WhatsappNotificationService.send_low_credit_alert(customer)
  end
end
