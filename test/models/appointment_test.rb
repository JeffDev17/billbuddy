require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @appointment = create_test_appointment(@customer)
  end

  test "should create appointment with valid attributes" do
    assert @appointment.valid?
  end

  test "should require customer" do
    @appointment.customer = nil
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:customer], "must exist"
  end

  test "should require scheduled_at" do
    @appointment.scheduled_at = nil
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:scheduled_at], "can't be blank"
  end

  test "should require duration" do
    @appointment.duration = nil
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:duration], "can't be blank"
  end

  test "should require status" do
    @appointment.status = nil
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:status], "can't be blank"
  end

  test "should validate duration is greater than 0" do
    @appointment.duration = 0
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:duration], "must be greater than 0"
  end

  test "should validate hourly rate is greater than 0" do
    @appointment.hourly_rate = -10
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:hourly_rate], "must be greater than 0"
  end

  test "should validate rate source inclusion" do
    @appointment.rate_source = "invalid_source"
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:rate_source], "is not included in the list"
  end

  test "should accept valid rate sources" do
    valid_sources = %w[custom monthly_package default]
    valid_sources.each do |source|
      @appointment.rate_source = source
      assert @appointment.valid?, "#{source} should be valid"
    end
  end

  test "should require cancellation_type when cancelled" do
    @appointment.status = "cancelled"
    @appointment.cancellation_type = nil
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:cancellation_type], "can't be blank"
  end

  test "should validate cancellation_type inclusion" do
    @appointment.status = "cancelled"
    @appointment.cancellation_type = nil
    assert_not @appointment.valid?
    assert_includes @appointment.errors[:cancellation_type], "can't be blank"
  end

  test "should accept valid cancellation types" do
    valid_types = %w[pending_reschedule with_revenue standard]
    valid_types.each do |type|
      @appointment.status = "cancelled"
      @appointment.cancellation_type = type
      assert @appointment.valid?, "#{type} should be valid"
    end
  end

  test "should scope appointments scheduled for date" do
    date = Date.current
    appointment = create_test_appointment(@customer, scheduled_at: date.beginning_of_day + 1.hour)
    scheduled_appointments = Appointment.scheduled_for_date(date)
    assert_includes scheduled_appointments, appointment
  end

  test "should scope today's appointments" do
    today_appointment = create_test_appointment(@customer, scheduled_at: Date.current.beginning_of_day + 1.hour)
    today_appointments = Appointment.today
    assert_includes today_appointments, today_appointment
  end

  test "should scope synced appointments" do
    @appointment.update!(google_event_id: "event123")
    synced_appointments = Appointment.synced_to_calendar
    assert_includes synced_appointments, @appointment
  end

  test "should scope unsynced appointments" do
    unsynced_appointments = Appointment.not_synced_to_calendar
    assert_includes unsynced_appointments, @appointment
  end

  test "should scope future appointments" do
    future_appointment = create_test_appointment(@customer, scheduled_at: 1.day.from_now)
    future_appointments = Appointment.future
    assert_includes future_appointments, future_appointment
  end

  test "should scope cancelled with revenue" do
    @appointment.update!(status: "cancelled", cancellation_type: "with_revenue")
    cancelled_with_revenue = Appointment.cancelled_with_revenue
    assert_includes cancelled_with_revenue, @appointment
  end

  test "should scope cancelled pending reschedule" do
    @appointment.update!(status: "cancelled", cancellation_type: "pending_reschedule")
    cancelled_pending = Appointment.cancelled_pending_reschedule
    assert_includes cancelled_pending, @appointment
  end

  test "should scope can be rescheduled" do
    @appointment.update!(status: "cancelled", cancellation_type: "pending_reschedule")
    reschedulable = Appointment.can_be_rescheduled
    assert_includes reschedulable, @appointment
  end

  test "should scope not reminded" do
    @appointment.update!(reminder_sent_at: nil)
    not_reminded = Appointment.not_reminded
    assert_includes not_reminded, @appointment
  end

  test "should calculate revenue amount" do
    @appointment.update!(status: "completed", duration: 60, hourly_rate: 100.0)
    expected_revenue = 60 * 100.0
    assert_equal expected_revenue, @appointment.revenue_amount
  end

  test "should return 0 for revenue amount when no hourly rate" do
    @appointment.update!(hourly_rate: nil)
    assert_equal 0, @appointment.revenue_amount
  end

  test "should check if needs reminder" do
    @appointment.update!(
      scheduled_at: 25.minutes.from_now,
      reminder_sent_at: nil
    )
    assert @appointment.needs_reminder?
  end

  test "should not need reminder if already sent" do
    @appointment.update!(
      scheduled_at: 25.minutes.from_now,
      reminder_sent_at: 1.hour.ago
    )
    assert_not @appointment.needs_reminder?
  end

  test "should not need reminder if too far in future" do
    @appointment.update!(
      scheduled_at: 2.hours.from_now,
      reminder_sent_at: nil
    )
    assert_not @appointment.needs_reminder?
  end

  test "should update to completed status" do
    @appointment.update!(status: "completed", completed_at: Time.current)
    assert_equal "completed", @appointment.status
    assert_not_nil @appointment.completed_at
  end

  test "should update to cancelled status" do
    @appointment.update!(status: "cancelled", cancellation_type: "standard")
    assert_equal "cancelled", @appointment.status
    assert_equal "standard", @appointment.cancellation_type
  end
end
