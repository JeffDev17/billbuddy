require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @subscription = create_test_subscription(@customer)
  end

  test "should create subscription" do
    assert @subscription
    assert_equal @customer, @subscription.customer
  end

  test "should require customer" do
    sub = Subscription.new(service_package: @subscription.service_package, start_date: Date.current, billing_day: 15)
    assert_not sub.valid?
  end

  test "should require service package" do
    sub = Subscription.new(customer: @customer, start_date: Date.current, billing_day: 15)
    assert_not sub.valid?
  end

  test "should require start date" do
    sub = Subscription.new(customer: @customer, service_package: @subscription.service_package, billing_day: 15)
    assert_not sub.valid?
  end

  test "should require billing day" do
    sub = Subscription.new(customer: @customer, service_package: @subscription.service_package, start_date: Date.current)
    assert_not sub.valid?
  end

  test "should validate billing day is between 1 and 31" do
    sub = Subscription.new(
      customer: @customer,
      service_package: @subscription.service_package,
      start_date: Date.current,
      billing_day: 0
    )
    assert_not sub.valid?

    sub.billing_day = 32
    assert_not sub.valid?

    sub.billing_day = 15
    assert sub.valid?
  end

  test "should have active status" do
    assert_equal "active", @subscription.status
  end

  test "should scope active subscriptions" do
    active_sub = create_test_subscription(@customer, status: :active)
    inactive_sub = create_test_subscription(@customer, status: :inactive)

    active_subs = Subscription.active
    assert_includes active_subs, active_sub
    assert_not_includes active_subs, inactive_sub
  end

  test "should scope current subscriptions" do
    current = create_test_subscription(@customer, end_date: 1.month.from_now)
    expired = create_test_subscription(@customer, end_date: 1.day.ago)

    current_subs = Subscription.current
    assert_includes current_subs, current
    assert_not_includes current_subs, expired
  end
end
