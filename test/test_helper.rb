ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    def create_test_user(attributes = {})
      User.create!({
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      }.merge(attributes))
    end

    def create_test_customer(user, attributes = {})
      Customer.create!({
        user: user,
        name: "Test Customer",
        email: "customer@example.com",
        phone: "+5511999999999",
        status: "active",
        plan_type: "credit"
      }.merge(attributes))
    end

    def create_test_appointment(customer, attributes = {})
      Appointment.create!({
        customer: customer,
        scheduled_at: 1.day.from_now,
        duration: 60,
        status: "scheduled"
      }.merge(attributes))
    end

    def create_test_payment(customer, attributes = {})
      Payment.create!({
        customer: customer,
        payment_type: "subscription",
        amount: 100.0,
        payment_date: 1.month.from_now,
        status: "pending",
        payment_method: "pix"
      }.merge(attributes))
    end

    def create_test_subscription(customer, attributes = {})
      service_package = attributes[:service_package] || ServicePackage.create!(
        name: "Test Package #{rand(1000)}",
        hours: 10,
        price: 500.0,
        active: true
      )

      Subscription.create!({
        customer: customer,
        service_package: service_package,
        start_date: Date.current,
        billing_day: 15,
        status: :active
      }.merge(attributes))
    end

    def create_test_customer_credit(customer, attributes = {})
      service_package = ServicePackage.create!(
        name: "Test Credit Package",
        hours: 5,
        price: 250.0,
        active: true
      )

      CustomerCredit.create!({
        customer: customer,
        service_package: service_package,
        purchase_date: Date.current,
        remaining_hours: 5
      }.merge(attributes))
    end

    def mock_whatsapp_api_success
      WhatsappApiService.stub_any_instance(:send_message, true) do
        yield
      end
    end

    def mock_whatsapp_api_failure
      WhatsappApiService.stub_any_instance(:send_message, proc { raise StandardError.new("API Error") }) do
        yield
      end
    end
  end
end
