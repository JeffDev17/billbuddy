require "test_helper"

class PaymentReminderServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user, phone: "+5511999999999")
    @payment = create_test_payment(@customer)
  end

  test "should send payment reminder for customer with phone" do
    mock_whatsapp_api_success do
      result = PaymentReminderService.send_payment_reminder(@customer)
      assert result
    end
  end

  test "should not send payment reminder for customer without phone" do
    @customer.update!(phone: nil)

    result = PaymentReminderService.send_payment_reminder(@customer)
    assert_not result
  end

  test "should not send payment reminder for customer with blank phone" do
    @customer.update!(phone: "")

    result = PaymentReminderService.send_payment_reminder(@customer)
    assert_not result
  end

  test "should send payment reminder with formatted phone" do
    formatted_phone = "+5511999999999"

    mock_whatsapp_api_success do
      result = PaymentReminderService.send_payment_reminder(@customer, formatted_phone)
      assert result
    end
  end

  test "should handle WhatsApp API errors gracefully" do
    mock_whatsapp_api_failure do
      result = PaymentReminderService.send_payment_reminder(@customer)
      assert_not result
    end
  end

  test "should create failed notification on error" do
    mock_whatsapp_api_failure do
      assert_difference "FailedNotification.count", 1 do
        PaymentReminderService.send_payment_reminder(@customer)
      end
    end
  end

  test "should send bulk payment reminders" do
    # Create overdue customer with subscription
    subscription = create_test_subscription(@customer)
    subscription.update!(billing_day: 15)

    # Mock the overdue customers query
    PaymentReminderService.stub(:find_overdue_customers, [ @customer ]) do
      mock_whatsapp_api_success do
        results = PaymentReminderService.send_bulk_payment_reminders(7)
        assert_equal 1, results[:success].length
        assert_equal 0, results[:failed].length
      end
    end
  end

  test "should handle bulk reminder failures" do
    # Create overdue customer with subscription
    subscription = create_test_subscription(@customer)
    subscription.update!(billing_day: 15)

    # Mock the overdue customers query
    PaymentReminderService.stub(:find_overdue_customers, [ @customer ]) do
      mock_whatsapp_api_failure do
        results = PaymentReminderService.send_bulk_payment_reminders(7)
        assert_equal 0, results[:success].length
        assert_equal 1, results[:failed].length
        assert_includes results[:failed].first[:error], "API Error"
      end
    end
  end

  test "should build correct payment reminder message" do
    message = PaymentReminderService.send(:build_message, @customer)

    assert_includes message, @customer.name
    assert_includes message, "pagamento pendente"
    assert_includes message, "BillBuddy"
  end

  test "should handle error and create failed notification" do
    error = StandardError.new("Test error")

    PaymentReminderService.send(:handle_error, @customer, error)

    failed_notification = FailedNotification.last
    assert_equal @customer, failed_notification.customer
    assert_equal "Test error", failed_notification.error_message
    assert_equal "payment_reminder", failed_notification.notification_type
  end

  test "should find overdue customers" do
    # Create subscription with billing day in the past
    subscription = create_test_subscription(@customer)
    subscription.update!(billing_day: 15)

    # Mock the date to make it overdue
    Date.stub(:current, Date.new(2024, 1, 25)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 7)
      assert_includes overdue_customers, @customer
    end
  end

  test "should not find non-overdue customers" do
    # Create subscription with billing day in the future
    subscription = create_test_subscription(@customer)
    subscription.update!(billing_day: 25)

    # Mock the date to make it not overdue
    Date.stub(:current, Date.new(2024, 1, 15)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 7)
      assert_not_includes overdue_customers, @customer
    end
  end

  test "should only find customers with active subscriptions" do
    # Create inactive subscription
    subscription = create_test_subscription(@customer)
    subscription.update!(status: "inactive", billing_day: 15)

    # Mock the date to make it overdue
    Date.stub(:current, Date.new(2024, 1, 25)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 7)
      assert_not_includes overdue_customers, @customer
    end
  end

  test "should handle multiple overdue customers" do
    customer2 = create_test_customer(@user, phone: "+5511888888888")
    subscription1 = create_test_subscription(@customer)
    subscription2 = create_test_subscription(customer2)

    subscription1.update!(billing_day: 15)
    subscription2.update!(billing_day: 15)

    # Mock the date to make them overdue
    Date.stub(:current, Date.new(2024, 1, 25)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 7)
      assert_includes overdue_customers, @customer
      assert_includes overdue_customers, customer2
    end
  end

  test "should handle no overdue customers" do
    # Create subscription with billing day in the future
    subscription = create_test_subscription(@customer)
    subscription.update!(billing_day: 25)

    # Mock the date to make it not overdue
    Date.stub(:current, Date.new(2024, 1, 15)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 7)
      assert_empty overdue_customers
    end
  end

  test "should respect days_overdue parameter" do
    subscription = create_test_subscription(@customer)
    subscription.update!(billing_day: 15)

    # Mock the date to make it overdue by 5 days
    Date.stub(:current, Date.new(2024, 1, 20)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 3)
      assert_not_includes overdue_customers, @customer
    end

    Date.stub(:current, Date.new(2024, 1, 20)) do
      overdue_customers = PaymentReminderService.send(:find_overdue_customers, 7)
      assert_includes overdue_customers, @customer
    end
  end
end
