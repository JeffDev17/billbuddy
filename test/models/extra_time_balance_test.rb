require "test_helper"

class ExtraTimeBalanceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @balance = ExtraTimeBalance.create!(
      customer: @customer,
      hours: 5,
      expiry_date: 1.month.from_now
    )
  end

  test "should create extra time balance with valid attributes" do
    assert @balance.valid?
    assert @balance.persisted?
  end

  test "should require customer" do
    @balance.customer = nil
    assert_not @balance.valid?
  end

  test "should require hours" do
    @balance.hours = nil
    assert_not @balance.valid?
  end

  test "should require expiry date" do
    @balance.expiry_date = nil
    assert_not @balance.valid?
  end

  test "should validate hours is greater than 0" do
    @balance.hours = 0
    assert_not @balance.valid?

    @balance.hours = -2
    assert_not @balance.valid?
  end

  test "should scope valid balances" do
    valid = ExtraTimeBalance.create!(
      customer: @customer,
      hours: 3,
      expiry_date: 1.week.from_now
    )
    expired = ExtraTimeBalance.create!(
      customer: @customer,
      hours: 2,
      expiry_date: 1.day.ago
    )

    valid_balances = ExtraTimeBalance.valid
    assert_includes valid_balances, valid
    assert_not_includes valid_balances, expired
  end

  test "should deduct hours when sufficient balance" do
    result = @balance.deduct_hours(2)
    assert result
    @balance.reload
    assert_equal 3, @balance.hours
  end

  test "should not deduct hours when insufficient balance" do
    result = @balance.deduct_hours(10)
    assert_not result
    @balance.reload
    assert_equal 5, @balance.hours
  end

  test "should deduct all remaining hours" do
    result = @balance.deduct_hours(5)
    assert result
    @balance.reload
    assert_operator @balance.hours, :>=, 0
  end
end
