class PaymentReminderJob < ApplicationJob
  queue_as :default
  retry_on WahaService::WahaError, wait: :exponentially_longer, attempts: 3

  def perform(customer_id)
    customer = Customer.find(customer_id)
    PaymentReminderService.send_payment_reminder(customer)
  end

  # You can also add a method to schedule reminders for all overdue customers
  def self.schedule_all_reminders(days_overdue = 7)
    results = PaymentReminderService.send_bulk_payment_reminders(days_overdue)
    
    # Log the results
    Rails.logger.info("Payment reminders sent successfully to #{results[:success].size} customers")
    Rails.logger.info("Payment reminders failed for #{results[:failed].size} customers") if results[:failed].any?
    
    results
  end
end