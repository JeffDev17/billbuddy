require "test_helper"

class AppointmentReminderServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user, phone: "+5511999999999")
    @appointment = create_test_appointment(@customer, scheduled_at: 25.minutes.from_now)
  end

  test "should send reminder for eligible appointment" do
    mock_whatsapp_api_success do
      result = AppointmentReminderService.send_reminder_for(@appointment)
      assert result
    end
  end

  test "should not send reminder if already sent" do
    @appointment.update!(reminder_sent_at: 1.hour.ago)

    result = AppointmentReminderService.send_reminder_for(@appointment)
    assert_not result
  end

  test "should not send reminder if too far in future" do
    @appointment.update!(scheduled_at: 2.hours.from_now)

    result = AppointmentReminderService.send_reminder_for(@appointment)
    assert_not result
  end

  test "should not send reminder if in the past" do
    @appointment.update!(scheduled_at: 1.hour.ago)

    result = AppointmentReminderService.send_reminder_for(@appointment)
    assert_not result
  end

  test "should not send reminder if customer has no phone" do
    @customer.update!(phone: nil)

    result = AppointmentReminderService.send_reminder_for(@appointment)
    assert_not result
  end

  test "should not send reminder if reminders disabled" do
    @user.update!(appointment_reminders_enabled: false)

    result = AppointmentReminderService.send_reminder_for(@appointment)
    assert_not result
  end

  test "should send reminder when forced" do
    @appointment.update!(reminder_sent_at: 1.hour.ago)

    mock_whatsapp_api_success do
      result = AppointmentReminderService.send_reminder_for(@appointment, force: true)
      assert result
    end
  end

  test "should mark reminder as sent after successful send" do
    mock_whatsapp_api_success do
      AppointmentReminderService.send_reminder_for(@appointment)
      @appointment.reload
      assert_not_nil @appointment.reminder_sent_at
    end
  end

  test "should handle WhatsApp API errors gracefully" do
    mock_whatsapp_api_failure do
      result = AppointmentReminderService.send_reminder_for(@appointment)
      assert_not result
    end
  end

  test "should create failed notification on error" do
    mock_whatsapp_api_failure do
      assert_difference "FailedNotification.count", 1 do
        AppointmentReminderService.send_reminder_for(@appointment)
      end
    end
  end

  test "should send upcoming reminders" do
    @user.update!(appointment_reminders_enabled: true)

    mock_whatsapp_api_success do
      result = AppointmentReminderService.send_upcoming_reminders(@user)
      assert result
    end
  end

  test "should not send upcoming reminders if disabled" do
    @user.update!(appointment_reminders_enabled: false)

    result = AppointmentReminderService.send_upcoming_reminders(@user)
    assert_not result
  end

  test "should preview upcoming reminders" do
    @user.update!(appointment_reminders_enabled: true)

    preview = AppointmentReminderService.preview_upcoming_reminders(@user)
    assert_equal 1, preview[:count]
    assert_includes preview[:appointments].map { |a| a[:id] }, @appointment.id
  end

  test "should build correct reminder message" do
    service = AppointmentReminderService.new(@user)
    message = service.send(:build_message, @appointment)

    assert_includes message, @customer.name
    assert_includes message, @appointment.scheduled_at.strftime("%H:%M")
    assert_includes message, @appointment.scheduled_at.strftime("%d/%m/%Y")
    assert_includes message, "#{@appointment.duration} minutos"
  end

  test "should format time correctly" do
    service = AppointmentReminderService.new(@user)
    time = service.send(:format_time, @appointment.scheduled_at)

    assert_equal @appointment.scheduled_at.strftime("%H:%M"), time
  end

  test "should format date correctly" do
    service = AppointmentReminderService.new(@user)
    date = service.send(:format_date, @appointment.scheduled_at)

    assert_equal @appointment.scheduled_at.strftime("%d/%m/%Y"), date
  end

  test "should format duration correctly" do
    service = AppointmentReminderService.new(@user)
    duration = service.send(:format_duration, @appointment.duration)

    assert_equal "#{@appointment.duration} minutos", duration
  end

  test "should find eligible appointments" do
    @user.update!(appointment_reminders_enabled: true)

    service = AppointmentReminderService.new(@user)
    eligible = service.send(:eligible_appointments)

    assert_includes eligible, @appointment
  end

  test "should not find ineligible appointments" do
    @appointment.update!(reminder_sent_at: 1.hour.ago)

    service = AppointmentReminderService.new(@user)
    eligible = service.send(:eligible_appointments)

    assert_not_includes eligible, @appointment
  end

  test "should handle multiple eligible appointments" do
    @user.update!(appointment_reminders_enabled: true)

    appointment2 = create_test_appointment(@customer, scheduled_at: 20.minutes.from_now)

    mock_whatsapp_api_success do
      result = AppointmentReminderService.send_upcoming_reminders(@user)
      assert result
    end
  end

  test "should handle no eligible appointments" do
    @user.update!(appointment_reminders_enabled: true)
    @appointment.update!(scheduled_at: 2.hours.from_now)

    result = AppointmentReminderService.send_upcoming_reminders(@user)
    assert_not result
  end
end
