require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @payment = create_test_payment(@customer)
  end

  test "should create payment with valid attributes" do
    assert @payment.valid?
  end

  test "should require customer" do
    @payment.customer = nil
    assert_not @payment.valid?
    assert_includes @payment.errors[:customer], "must exist"
  end

  test "should require amount" do
    @payment.amount = nil
    assert_not @payment.valid?
    assert_includes @payment.errors[:amount], "can't be blank"
  end

  test "should require payment_date" do
    @payment.payment_date = nil
    assert_not @payment.valid?
    assert_includes @payment.errors[:payment_date], "can't be blank"
  end

  test "should require status" do
    @payment.status = nil
    assert_not @payment.valid?
    assert_includes @payment.errors[:status], "can't be blank"
  end

  test "should validate amount is greater than 0" do
    @payment.amount = -10
    assert_not @payment.valid?
    assert_includes @payment.errors[:amount], "must be greater than 0"
  end

  test "should validate status inclusion" do
    @payment.status = nil
    assert_not @payment.valid?
    assert_includes @payment.errors[:status], "can't be blank"
  end

  test "should accept valid statuses" do
    valid_statuses = %w[pending paid cancelled]
    valid_statuses.each do |status|
      @payment.status = status
      assert @payment.valid?, "#{status} should be valid"
    end
  end

  test "should scope pending payments" do
    @payment.update!(status: "pending")
    pending_payments = Payment.pending
    assert_includes pending_payments, @payment
  end

  test "should scope paid payments" do
    @payment.update!(status: "paid")
    paid_payments = Payment.paid
    assert_includes paid_payments, @payment
  end

  test "should scope cancelled payments" do
    @payment.update!(status: "cancelled")
    cancelled_payments = Payment.cancelled_payments
    assert_includes cancelled_payments, @payment
  end

  test "should scope payments for month" do
    month_date = Date.current
    @payment.update!(payment_date: month_date)
    monthly_payments = Payment.this_month
    assert_includes monthly_payments, @payment
  end

  test "should calculate net amount" do
    @payment.update!(amount: 100.0, fees: 5.0)
    assert_equal 95.0, @payment.net_amount
  end

  test "should return amount when no fees" do
    @payment.update!(amount: 100.0, fees: nil)
    assert_equal 100.0, @payment.net_amount
  end

  test "should check if payment is processed" do
    @payment.update!(received_at: Time.current)
    assert @payment.processed?
  end

  test "should not be processed when no received_at" do
    @payment.update!(received_at: nil)
    assert_not @payment.processed?
  end

  test "should mark as paid" do
    @payment.mark_as_paid!
    assert_equal "paid", @payment.status
    assert_not_nil @payment.received_at
  end

  test "should mark as paid with processed_by" do
    @payment.mark_as_paid!(processed_by: "admin")
    assert_equal "paid", @payment.status
    assert_equal "admin", @payment.processed_by
  end

  test "should get payment history for customer" do
    payment1 = create_test_payment(@customer, amount: 100.0)
    payment2 = create_test_payment(@customer, amount: 150.0)

    history = Payment.payment_history_for(@customer)
    assert_includes history, payment1
    assert_includes history, payment2
  end

  test "should scope by payment method" do
    @payment.update!(payment_method: "pix")
    pix_payments = Payment.by_payment_method("pix")
    assert_includes pix_payments, @payment
  end

  test "should scope recent first" do
    @payment.update!(payment_date: 2.days.ago)
    payment1 = create_test_payment(@customer, payment_date: 1.day.ago)

    recent_payments = Payment.where(customer: @customer).recent_first
    assert_equal payment1.id, recent_payments.first.id
  end
end
