require "test_helper"

class ServicePackageTest < ActiveSupport::TestCase
  def setup
    @package = ServicePackage.create!(
      name: "Basic Package",
      hours: 10,
      price: 500.0,
      active: true
    )
  end

  test "should create service package with valid attributes" do
    assert @package.valid?
    assert @package.persisted?
  end

  test "should require name" do
    @package.name = nil
    assert_not @package.valid?
  end

  test "should require hours" do
    @package.hours = nil
    assert_not @package.valid?
  end

  test "should require price" do
    @package.price = nil
    assert_not @package.valid?
  end

  test "should validate hours is greater than 0" do
    @package.hours = 0
    assert_not @package.valid?

    @package.hours = -5
    assert_not @package.valid?
  end

  test "should validate price is greater than 0" do
    @package.price = 0
    assert_not @package.valid?

    @package.price = -100
    assert_not @package.valid?
  end

  test "should scope active packages" do
    active_pkg = ServicePackage.create!(name: "Active", hours: 5, price: 250, active: true)
    inactive_pkg = ServicePackage.create!(name: "Inactive", hours: 5, price: 250, active: false)

    active_packages = ServicePackage.active
    assert_includes active_packages, active_pkg
    assert_not_includes active_packages, inactive_pkg
  end

  test "should have customer credits association" do
    assert_respond_to @package, :customer_credits
  end

  test "should have subscriptions association" do
    assert_respond_to @package, :subscriptions
  end
end
