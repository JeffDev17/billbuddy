require "test_helper"

class AppointmentWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    sign_in @user
  end

  test "complete appointment workflow" do
    # 1. Create appointment
    assert_difference("Appointment.count") do
      post appointments_url, params: {
        appointment: {
          customer_id: @customer.id,
          scheduled_at: 1.day.from_now,
          duration: 60,
          status: "scheduled"
        }
      }
    end

    appointment = Appointment.last
    assert_equal "scheduled", appointment.status

    # 2. Edit appointment
    patch appointment_url(appointment), params: {
      appointment: {
        duration: 90,
        hourly_rate: 100.0
      }
    }

    appointment.reload
    assert_equal 90, appointment.duration
    assert_equal 100.0, appointment.hourly_rate

    # 3. Mark as completed
    post mark_completed_appointment_url(appointment)
    appointment.reload
    assert_equal "completed", appointment.status
    assert_not_nil appointment.completed_at
  end

  test "appointment cancellation workflow" do
    appointment = create_test_appointment(@customer)

    # 1. Get cancellation options
    get cancellation_options_appointment_url(appointment)
    assert_response :success

    # 2. Cancel appointment
    post mark_cancelled_appointment_url(appointment), params: {
      cancellation_type: "with_revenue"
    }

    appointment.reload
    assert_equal "cancelled", appointment.status
    assert_equal "with_revenue", appointment.cancellation_type

    # 3. Reschedule appointment
    new_time = 3.days.from_now
    post reschedule_appointment_url(appointment), params: {
      scheduled_at: new_time
    }

    appointment.reload
    assert_equal "scheduled", appointment.status
    assert_equal new_time.to_date, appointment.scheduled_at.to_date
  end

  test "bulk appointment operations" do
    appointment1 = create_test_appointment(@customer)
    appointment2 = create_test_appointment(@customer)

    # 1. Bulk mark as completed
    post bulk_mark_completed_appointments_url, params: {
      appointment_ids: [ appointment1.id, appointment2.id ]
    }

    appointment1.reload
    appointment2.reload
    assert_equal "completed", appointment1.status
    assert_equal "completed", appointment2.status

    # 2. Bulk delete by customer
    appointment3 = create_test_appointment(@customer)
    delete bulk_delete_by_customer_appointments_url(@customer)

    assert_equal 0, @customer.appointments.count
  end

  test "appointment generation workflow" do
    # 1. Preview current month
    get preview_current_month_appointments_url
    assert_response :success

    # 2. Fill current month
    post fill_current_month_appointments_url
    assert_redirected_to appointments_url

    # 3. Preview next month
    get preview_next_month_appointments_url
    assert_response :success

    # 4. Generate next month
    post generate_next_month_appointments_url
    assert_redirected_to appointments_url

    # 5. Get month stats
    get get_month_stats_appointments_url, params: {
      month: Date.current.strftime("%Y-%m")
    }
    assert_response :success
  end

  test "appointment sync workflow" do
    appointment = create_test_appointment(@customer)

    # 1. Review sync
    get review_sync_appointments_url
    assert_response :success

    # 2. Sync all appointments
    post sync_all_appointments_appointments_url
    assert_redirected_to appointments_url

    # 3. Sync upcoming appointments
    post sync_upcoming_appointments_appointments_url
    assert_redirected_to appointments_url

    # 4. Confirm sync
    post confirm_sync_appointments_url, params: {
      scope: "all"
    }
    assert_redirected_to appointments_url
  end

  test "auto generation workflow" do
    # 1. Get manage auto generation
    get manage_auto_generation_appointments_url
    assert_response :success

    # 2. Setup auto generation
    post setup_auto_generation_appointments_url, params: {
      auto_generation: {
        enabled: true,
        days_ahead: 30
      }
    }
    assert_redirected_to appointments_url

    # 3. Run auto generation now
    post run_auto_generation_now_appointments_url
    assert_redirected_to appointments_url

    # 4. Cancel auto generation
    post cancel_auto_generation_appointments_url
    assert_redirected_to appointments_url
  end

  test "custom period generation" do
    start_date = Date.current
    end_date = 1.month.from_now

    # 1. Generate custom period
    post generate_custom_period_appointments_url, params: {
      start_date: start_date.strftime("%Y-%m-%d"),
      end_date: end_date.strftime("%Y-%m-%d")
    }
    assert_redirected_to appointments_url

    # 2. Generate specific month
    post generate_specific_month_appointments_url, params: {
      month: Date.current.strftime("%Y-%m")
    }
    assert_redirected_to appointments_url

    # 3. Delete month appointments
    delete delete_month_appointments_appointments_url, params: {
      month: Date.current.strftime("%Y-%m")
    }
    assert_redirected_to appointments_url
  end

  test "appointment filtering workflow" do
    # Create appointments with different dates and statuses
    past_appointment = create_test_appointment(@customer, scheduled_at: 1.day.ago)
    future_appointment = create_test_appointment(@customer, scheduled_at: 1.day.from_now)
    completed_appointment = create_test_appointment(@customer, scheduled_at: 2.days.from_now)
    completed_appointment.update!(status: "completed")

    # 1. Filter by date range
    get appointments_url, params: {
      start_date: Date.current.strftime("%Y-%m-%d"),
      end_date: 1.week.from_now.strftime("%Y-%m-%d")
    }
    assert_response :success

    # 2. Filter by status
    get appointments_url, params: {
      status: "completed"
    }
    assert_response :success

    # 3. Filter by customer
    get appointments_url, params: {
      customer_id: @customer.id
    }
    assert_response :success
  end

  test "appointment with customer workflow" do
    # 1. Create appointment
    appointment = create_test_appointment(@customer)

    # 2. Sync appointments for customer
    post sync_appointments_customer_url(@customer)
    assert_redirected_to customer_url(@customer)

    # 3. Sync upcoming appointments for customer
    post sync_upcoming_appointments_customer_url(@customer)
    assert_redirected_to customer_url(@customer)

    # 4. Mark appointment as completed
    post mark_completed_appointment_url(appointment)
    assert_redirected_to appointments_url

    # 5. Verify appointment is completed
    appointment.reload
    assert_equal "completed", appointment.status
  end
end
