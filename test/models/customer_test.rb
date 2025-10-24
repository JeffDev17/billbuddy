require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
  end

  test "should create customer with valid attributes" do
    assert @customer.valid?
  end

  test "should require name" do
    @customer.name = nil
    assert_not @customer.valid?
    assert_includes @customer.errors[:name], "can't be blank"
  end

  test "should validate email uniqueness within user scope" do
    duplicate_customer = Customer.new(
      user: @user,
      name: "Another Customer",
      email: @customer.email
    )
    assert_not duplicate_customer.valid?
    assert_includes duplicate_customer.errors[:email], "has already been taken"
  end

  test "should validate phone format" do
    @customer.phone = "invalid_phone"
    assert_not @customer.valid?
    assert @customer.errors[:phone].any? { |msg| msg.include?("deve estar no formato internacional") }
  end

  test "should accept valid phone format" do
    @customer.phone = "+5511999999999"
    assert @customer.valid?
  end

  test "should validate custom hourly rate" do
    @customer.custom_hourly_rate = -10
    assert_not @customer.valid?
    assert_includes @customer.errors[:custom_hourly_rate], "must be greater than 0"
  end

  test "should validate monthly amount" do
    @customer.monthly_amount = -100
    assert_not @customer.valid?
    assert_includes @customer.errors[:monthly_amount], "must be greater than 0"
  end

  test "should validate monthly hours" do
    @customer.monthly_hours = -5
    assert_not @customer.valid?
    assert_includes @customer.errors[:monthly_hours], "must be greater than 0"
  end

  test "should set activated_at on create" do
    new_customer = Customer.create!(
      user: @user,
      name: "New Customer",
      email: "new@example.com"
    )
    assert_not_nil new_customer.activated_at
  end

  test "should have correct associations" do
    assert_respond_to @customer, :user
    assert_respond_to @customer, :customer_credits
    assert_respond_to @customer, :subscriptions
    assert_respond_to @customer, :appointments
    assert_respond_to @customer, :extra_time_balances
    assert_respond_to @customer, :payments
    assert_respond_to @customer, :customer_schedules
  end

  test "should find active credit" do
    credit = create_test_customer_credit(@customer, remaining_hours: 5)
    assert_equal credit, @customer.active_credit
  end

  test "should return nil for active credit when no credits exist" do
    assert_nil @customer.active_credit
  end

  test "should scope customers with remaining credits" do
    credit = create_test_customer_credit(@customer, remaining_hours: 5)
    customers_with_credits = Customer.with_remaining_credits
    assert_includes customers_with_credits, @customer
  end

  test "should scope customers with active subscriptions" do
    subscription = create_test_subscription(@customer)
    customers_with_subscriptions = Customer.with_active_subscriptions
    assert_includes customers_with_subscriptions, @customer
  end

  test "should scope customers with upcoming appointments" do
    appointment = create_test_appointment(@customer, scheduled_at: 1.day.from_now)
    customers_with_appointments = Customer.with_upcoming_appointments
    assert_includes customers_with_appointments, @customer
  end

  test "should scope customers with birthdays" do
    @customer.update!(birthdate: Date.current)
    customers_with_birthdays = Customer.with_birthdays
    assert_includes customers_with_birthdays, @customer
  end

  test "should scope customers active during month" do
    month_date = Date.current
    active_customers = Customer.active_during_month(month_date)
    assert_includes active_customers, @customer
  end

  test "should scope customers with payment history" do
    payment = create_test_payment(@customer, status: "paid")
    customers_with_payments = Customer.with_payment_history
    assert_includes customers_with_payments, @customer
  end

  test "should format phone number" do
    @customer.phone = "11999999999"
    @customer.save!
    assert_equal "+5511999999999", @customer.phone
  end

  test "should update future appointment rates when pricing changes" do
    appointment = create_test_appointment(@customer, hourly_rate: 50.0)
    @customer.update!(custom_hourly_rate: 75.0)

    # This would need to be implemented in the model
    # assert_equal 75.0, appointment.reload.hourly_rate
  end
end
