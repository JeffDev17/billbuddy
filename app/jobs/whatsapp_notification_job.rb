class WhatsappNotificationJob < ApplicationJob
  queue_as :default
  retry_on WahaService::WahaError, wait: :exponentially_longer, attempts: 3

  def perform(customer_id)
    customer = Customer.find(customer_id)
    WhatsappNotificationService.send_low_credit_alert(customer)
  end
end
