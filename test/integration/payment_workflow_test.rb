require "test_helper"

class PaymentWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    sign_in @user
  end

  test "complete payment workflow" do
    # 1. Create payment
    assert_difference("Payment.count") do
      post customer_payments_url(@customer), params: {
        payment: {
          amount: 500.0,
          due_date: 1.month.from_now,
          status: "pending"
        }
      }
    end

    payment = Payment.last
    assert_equal 500.0, payment.amount
    assert_equal "pending", payment.status

    # 2. Update payment
    patch customer_payment_url(@customer, payment), params: {
      payment: {
        amount: 600.0
      }
    }

    payment.reload
    assert_equal 600.0, payment.amount

    # 3. Mark as paid
    post mark_paid_payments_url, params: {
      payment_id: payment.id
    }

    payment.reload
    assert_equal "paid", payment.status
    assert_not_nil payment.paid_at
  end

  test "payment reminder workflow" do
    payment = create_test_payment(@customer)

    # 1. Get payment reminder form
    get payment_reminder_form_customer_url(@customer)
    assert_response :success

    # 2. Send payment reminder
    mock_whatsapp_api_success do
      post send_payment_reminder_customer_url(@customer), params: {
        message: "Payment reminder message"
      }
      assert_redirected_to customer_url(@customer)
    end
  end

  test "bulk payment operations" do
    payment1 = create_test_payment(@customer, amount: 100.0)
    payment2 = create_test_payment(@customer, amount: 200.0)
    payment3 = create_test_payment(@customer, amount: 300.0)

    # 1. Bulk mark as paid
    post bulk_mark_paid_payments_url, params: {
      payment_ids: [ payment1.id, payment2.id ]
    }

    payment1.reload
    payment2.reload
    payment3.reload
    assert_equal "paid", payment1.status
    assert_equal "paid", payment2.status
    assert_equal "pending", payment3.status

    # 2. Unmark payment
    post unmark_paid_payments_url, params: {
      payment_id: payment1.id
    }

    payment1.reload
    assert_equal "pending", payment1.status
  end

  test "payment status updates" do
    payment = create_test_payment(@customer)

    # 1. Update payment status
    post update_payment_status_payments_url, params: {
      payment_id: payment.id,
      status: "paid"
    }

    payment.reload
    assert_equal "paid", payment.status

    # 2. Update payment amount
    post update_payment_amount_payments_url, params: {
      payment_id: payment.id,
      amount: 750.0
    }

    payment.reload
    assert_equal 750.0, payment.amount
  end

  test "monthly payment checklist" do
    # Create payments for current month
    payment1 = create_test_payment(@customer, due_date: Date.current)
    payment2 = create_test_payment(@customer, due_date: Date.current + 1.day)

    # 1. Get monthly checklist
    get monthly_checklist_payments_url
    assert_response :success

    # 2. Mark payments as paid
    post mark_paid_payments_url, params: {
      payment_id: payment1.id
    }

    payment1.reload
    assert_equal "paid", payment1.status
  end

  test "payment history workflow" do
    # Create payments with different statuses
    paid_payment = create_test_payment(@customer, status: "paid")
    pending_payment = create_test_payment(@customer, status: "pending")
    cancelled_payment = create_test_payment(@customer, status: "cancelled")

    # 1. Get payment history
    get history_customer_payments_url(@customer)
    assert_response :success

    # 2. Verify all payments are shown
    assert_select "td", text: paid_payment.amount.to_s
    assert_select "td", text: pending_payment.amount.to_s
    assert_select "td", text: cancelled_payment.amount.to_s
  end

  test "payment filtering workflow" do
    # Create payments with different amounts and statuses
    high_payment = create_test_payment(@customer, amount: 1000.0, status: "paid")
    low_payment = create_test_payment(@customer, amount: 100.0, status: "pending")

    # 1. Filter by status
    get payments_url, params: {
      status: "paid"
    }
    assert_response :success

    # 2. Filter by amount range
    get payments_url, params: {
      min_amount: 500
    }
    assert_response :success

    # 3. Filter by date range
    get payments_url, params: {
      start_date: Date.current.strftime("%Y-%m-%d"),
      end_date: 1.month.from_now.strftime("%Y-%m-%d")
    }
    assert_response :success
  end

  test "payment with customer workflow" do
    # 1. Create payment
    payment = create_test_payment(@customer)

    # 2. Update payment amount
    patch customer_payment_url(@customer, payment), params: {
      payment: {
        amount: 800.0
      }
    }

    payment.reload
    assert_equal 800.0, payment.amount

    # 3. Mark as paid
    post mark_paid_payments_url, params: {
      payment_id: payment.id
    }

    payment.reload
    assert_equal "paid", payment.status

    # 4. Verify payment is marked as paid
    assert_not_nil payment.paid_at
  end

  test "payment overdue workflow" do
    # Create overdue payment
    overdue_payment = create_test_payment(@customer, due_date: 5.days.ago, status: "pending")

    # 1. Check if payment is overdue
    assert overdue_payment.overdue?

    # 2. Update status to overdue
    overdue_payment.check_overdue_status!
    assert_equal "overdue", overdue_payment.status

    # 3. Send payment reminder
    mock_whatsapp_api_success do
      post send_payment_reminder_customer_url(@customer), params: {
        message: "Overdue payment reminder"
      }
      assert_redirected_to customer_url(@customer)
    end
  end

  test "payment cancellation workflow" do
    payment = create_test_payment(@customer)

    # 1. Cancel payment
    payment.mark_cancelled!
    assert_equal "cancelled", payment.status
    assert_not_nil payment.cancelled_at

    # 2. Verify payment cannot be marked as paid
    assert_raises(StandardError) do
      payment.mark_paid!
    end
  end

  test "payment with subscription workflow" do
    # Create subscription
    subscription = create_test_subscription(@customer)

    # 1. Create payment for subscription
    payment = create_test_payment(@customer, amount: subscription.service_package.price)

    # 2. Mark payment as paid
    payment.mark_paid!

    # 3. Verify subscription is still active
    subscription.reload
    assert_equal "active", subscription.status
  end

  test "payment with credit workflow" do
    # Create customer credit
    credit = create_test_customer_credit(@customer, remaining_hours: 10)

    # 1. Create payment for credit purchase
    payment = create_test_payment(@customer, amount: credit.service_package.price)

    # 2. Mark payment as paid
    payment.mark_paid!

    # 3. Verify credit is available
    assert_equal 10, credit.remaining_hours
  end
end
