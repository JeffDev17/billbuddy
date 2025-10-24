require "test_helper"

class FailedNotificationTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @notification = FailedNotification.create!(
      customer: @customer,
      notification_type: "payment_reminder",
      error_message: "API connection failed"
    )
  end

  test "should create failed notification with valid attributes" do
    assert @notification.valid?
    assert @notification.persisted?
  end

  test "should require customer" do
    @notification.customer = nil
    assert_not @notification.valid?
  end

  test "should require notification type" do
    @notification.notification_type = nil
    assert_not @notification.valid?
  end

  test "should require error message" do
    @notification.error_message = nil
    assert_not @notification.valid?
  end

  test "should scope retryable notifications" do
    recent = FailedNotification.create!(
      customer: @customer,
      notification_type: "appointment_reminder",
      error_message: "Temporary failure",
      created_at: 1.hour.ago
    )
    old = FailedNotification.create!(
      customer: @customer,
      notification_type: "appointment_reminder",
      error_message: "Old failure",
      created_at: 25.hours.ago
    )

    retryable = FailedNotification.retryable
    assert_includes retryable, recent
    assert_not_includes retryable, old
  end
end
