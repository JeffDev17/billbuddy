require "test_helper"

class CustomerCreditTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @credit = create_test_customer_credit(@customer)
  end

  test "should create customer credit with valid attributes" do
    assert @credit.valid?
    assert @credit.persisted?
  end

  test "should require customer" do
    @credit.customer = nil
    assert_not @credit.valid?
  end

  test "should require remaining hours" do
    @credit.remaining_hours = nil
    assert_not @credit.valid?
  end

  test "should require purchase date" do
    @credit.purchase_date = nil
    assert_not @credit.valid?
  end

  test "should belong to service package" do
    assert_respond_to @credit, :service_package
    assert_not_nil @credit.service_package
  end

  test "should deduct hours correctly" do
    initial_hours = @credit.remaining_hours
    @credit.deduct_hours(2)
    @credit.reload
    assert_equal initial_hours - 2, @credit.remaining_hours
  end

  test "should return package name for packaged credit" do
    assert_equal @credit.service_package.name, @credit.package_name
  end

  test "should return package name" do
    assert_equal @credit.service_package.name, @credit.package_name
  end

  test "should set initial hours from package on create" do
    package = ServicePackage.create!(name: "Test", hours: 15, price: 750, active: true)
    credit = CustomerCredit.create!(
      customer: @customer,
      service_package: package,
      purchase_date: Date.current
    )
    assert_equal 15, credit.remaining_hours
  end

  test "should not override custom hours even with package" do
    package = ServicePackage.create!(name: "Test", hours: 15, price: 750, active: true)
    credit = CustomerCredit.create!(
      customer: @customer,
      service_package: package,
      remaining_hours: 20,
      purchase_date: Date.current
    )
    assert_equal 20, credit.remaining_hours
  end

  test "should identify packaged credit" do
    assert_not @credit.custom_credit?
    assert @credit.service_package.present?
  end
end
