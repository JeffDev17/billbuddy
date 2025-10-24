require "test_helper"

class CustomerScheduleTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @schedule = CustomerSchedule.create!(
      customer: @customer,
      day_of_week: 1,
      start_time: Time.zone.parse("14:00"),
      duration: 60,
      enabled: true
    )
  end

  test "should create schedule with valid attributes" do
    assert @schedule.valid?
    assert @schedule.persisted?
  end

  test "should require customer" do
    @schedule.customer = nil
    assert_not @schedule.valid?
  end

  test "should require day of week" do
    @schedule.day_of_week = nil
    assert_not @schedule.valid?
  end

  test "should validate day of week is between 0 and 6" do
    @schedule.day_of_week = -1
    assert_not @schedule.valid?

    @schedule.day_of_week = 7
    assert_not @schedule.valid?

    @schedule.day_of_week = 3
    assert @schedule.valid?
  end

  test "should require start time" do
    @schedule.start_time = nil
    assert_not @schedule.valid?
  end

  test "should require duration" do
    @schedule.duration = nil
    assert_not @schedule.valid?
  end

  test "should validate duration is greater than 0" do
    @schedule.duration = 0
    assert_not @schedule.valid?

    @schedule.duration = -30
    assert_not @schedule.valid?
  end

  test "should scope enabled schedules" do
    enabled = CustomerSchedule.create!(
      customer: @customer,
      day_of_week: 2,
      start_time: Time.zone.parse("10:00"),
      duration: 60,
      enabled: true
    )
    disabled = CustomerSchedule.create!(
      customer: @customer,
      day_of_week: 3,
      start_time: Time.zone.parse("15:00"),
      duration: 60,
      enabled: false
    )

    enabled_schedules = CustomerSchedule.enabled
    assert_includes enabled_schedules, enabled
    assert_not_includes enabled_schedules, disabled
  end

  test "should scope schedules for specific day" do
    monday = CustomerSchedule.create!(
      customer: @customer,
      day_of_week: 1,
      start_time: Time.zone.parse("10:00"),
      duration: 60,
      enabled: true
    )
    tuesday = CustomerSchedule.create!(
      customer: @customer,
      day_of_week: 2,
      start_time: Time.zone.parse("10:00"),
      duration: 60,
      enabled: true
    )

    monday_schedules = CustomerSchedule.for_day(1)
    assert_includes monday_schedules, monday
    assert_not_includes monday_schedules, tuesday
  end

  test "should return day name" do
    @schedule.day_of_week = 1
    assert_equal "Segunda-feira", @schedule.day_name
  end

  test "should format time correctly" do
    assert_equal "14:00", @schedule.formatted_time
  end

  test "should format full schedule" do
    result = @schedule.formatted_schedule
    assert_includes result, "Segunda-feira"
    assert_includes result, "14:00"
    assert_includes result, "60"
  end

  test "should check if applies to date" do
    monday = Date.new(2025, 10, 27)
    tuesday = Date.new(2025, 10, 28)

    assert @schedule.applies_to_date?(monday)
    assert_not @schedule.applies_to_date?(tuesday)
  end

  test "should not apply if disabled" do
    @schedule.update!(enabled: false)
    monday = Date.new(2025, 10, 27)
    assert_not @schedule.applies_to_date?(monday)
  end

  test "should create appointment time for valid date" do
    monday = Date.new(2025, 10, 27)
    time = @schedule.appointment_time_for_date(monday)

    assert_equal 2025, time.year
    assert_equal 10, time.month
    assert_equal 27, time.day
    assert_equal 14, time.hour
    assert_equal 0, time.min
  end

  test "should return nil for wrong day of week" do
    tuesday = Date.new(2025, 10, 28)
    assert_nil @schedule.appointment_time_for_date(tuesday)
  end
end
