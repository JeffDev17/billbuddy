require "test_helper"

class AppointmentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    @appointment = create_test_appointment(@customer)
    sign_in @user
  end

  test "should get index" do
    get appointments_url
    assert_response :success
    assert_select "h1", text: /Compromissos/
  end

  test "should get new" do
    get new_appointment_url
    assert_response :success
  end

  test "should create appointment" do
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

    assert_redirected_to appointments_url
    assert_equal @customer.id, Appointment.last.customer_id
  end

  test "should not create appointment with invalid attributes" do
    assert_no_difference("Appointment.count") do
      post appointments_url, params: {
        appointment: {
          customer_id: @customer.id,
          scheduled_at: nil,
          duration: 0,
          status: "scheduled"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_appointment_url(@appointment)
    assert_response :success
  end

  test "should update appointment" do
    patch appointment_url(@appointment), params: {
      appointment: {
        scheduled_at: 2.days.from_now,
        duration: 90
      }
    }

    assert_redirected_to appointments_url
    @appointment.reload
    assert_equal 90, @appointment.duration
  end

  test "should not update appointment with invalid attributes" do
    patch appointment_url(@appointment), params: {
      appointment: {
        duration: 0
      }
    }

    assert_response :unprocessable_entity
    @appointment.reload
    assert_not_equal 0, @appointment.duration
  end

  test "should destroy appointment" do
    assert_difference("Appointment.count", -1) do
      delete appointment_url(@appointment)
    end

    assert_redirected_to appointments_url
  end

  test "should mark appointment as completed" do
    post mark_completed_appointment_url(@appointment)

    assert_redirected_to appointments_url
    @appointment.reload
    assert_equal "completed", @appointment.status
    assert_not_nil @appointment.completed_at
  end

  test "should mark appointment as cancelled" do
    post mark_cancelled_appointment_url(@appointment), params: {
      cancellation_type: "standard"
    }

    assert_redirected_to appointments_url
    @appointment.reload
    assert_equal "cancelled", @appointment.status
    assert_equal "standard", @appointment.cancellation_type
  end

  test "should get cancellation options" do
    get cancellation_options_appointment_url(@appointment)
    assert_response :success
  end

  test "should reschedule appointment" do
    new_time = 3.days.from_now

    post reschedule_appointment_url(@appointment), params: {
      scheduled_at: new_time
    }

    assert_redirected_to appointments_url
    @appointment.reload
    assert_equal new_time.to_date, @appointment.scheduled_at.to_date
  end

  test "should bulk mark appointments as completed" do
    appointment2 = create_test_appointment(@customer)

    post bulk_mark_completed_appointments_url, params: {
      appointment_ids: [ @appointment.id, appointment2.id ]
    }

    assert_redirected_to appointments_url
    @appointment.reload
    appointment2.reload
    assert_equal "completed", @appointment.status
    assert_equal "completed", appointment2.status
  end

  test "should bulk delete appointments by customer" do
    appointment2 = create_test_appointment(@customer)

    delete bulk_delete_by_customer_appointments_url(@customer)

    assert_redirected_to appointments_url
    assert_equal 0, @customer.appointments.count
  end

  test "should sync all appointments" do
    post sync_all_appointments_appointments_url
    assert_redirected_to appointments_url
  end

  test "should sync upcoming appointments" do
    post sync_upcoming_appointments_appointments_url
    assert_redirected_to appointments_url
  end

  test "should get review sync" do
    get review_sync_appointments_url
    assert_response :success
  end

  test "should confirm sync" do
    post confirm_sync_appointments_url, params: {
      scope: "all"
    }
    assert_redirected_to appointments_url
  end

  test "should get manage auto generation" do
    get manage_auto_generation_appointments_url
    assert_response :success
  end

  test "should setup auto generation" do
    post setup_auto_generation_appointments_url, params: {
      auto_generation: {
        enabled: true,
        days_ahead: 30
      }
    }
    assert_redirected_to appointments_url
  end

  test "should cancel auto generation" do
    post cancel_auto_generation_appointments_url
    assert_redirected_to appointments_url
  end

  test "should run auto generation now" do
    post run_auto_generation_now_appointments_url
    assert_redirected_to appointments_url
  end

  test "should fill current month" do
    post fill_current_month_appointments_url
    assert_redirected_to appointments_url
  end

  test "should preview current month" do
    get preview_current_month_appointments_url
    assert_response :success
  end

  test "should generate next month" do
    post generate_next_month_appointments_url
    assert_redirected_to appointments_url
  end

  test "should preview next month" do
    get preview_next_month_appointments_url
    assert_response :success
  end

  test "should generate custom period" do
    post generate_custom_period_appointments_url, params: {
      start_date: Date.current,
      end_date: 1.month.from_now
    }
    assert_redirected_to appointments_url
  end

  test "should get month stats" do
    get get_month_stats_appointments_url, params: {
      month: Date.current.strftime("%Y-%m")
    }
    assert_response :success
  end

  test "should delete month appointments" do
    delete delete_month_appointments_appointments_url, params: {
      month: Date.current.strftime("%Y-%m")
    }
    assert_redirected_to appointments_url
  end

  test "should generate specific month" do
    post generate_specific_month_appointments_url, params: {
      month: Date.current.strftime("%Y-%m")
    }
    assert_redirected_to appointments_url
  end

  test "should get preview generation" do
    get preview_generation_appointments_url
    assert_response :success
  end

  test "should confirm generation" do
    post confirm_generation_appointments_url, params: {
      generation_params: {
        start_date: Date.current,
        end_date: 1.month.from_now
      }
    }
    assert_redirected_to appointments_url
  end

  test "should filter appointments by date range" do
    start_date = Date.current.beginning_of_week
    end_date = Date.current.end_of_week

    get appointments_url, params: {
      start_date: start_date.strftime("%Y-%m-%d"),
      end_date: end_date.strftime("%Y-%m-%d")
    }
    assert_response :success
  end

  test "should filter appointments by customer" do
    customer2 = create_test_customer(@user)
    appointment2 = create_test_appointment(customer2)

    get appointments_url, params: {
      customer_id: @customer.id
    }
    assert_response :success
  end

  test "should filter appointments by status" do
    @appointment.update!(status: "completed")

    get appointments_url, params: {
      status: "completed"
    }
    assert_response :success
  end

  test "should require authentication" do
    sign_out @user

    get appointments_url
    assert_redirected_to new_user_session_url
  end

  test "should only show user's own appointments" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)
    other_appointment = create_test_appointment(other_customer)

    get appointments_url
    assert_response :success
    assert_select "td", text: @customer.name
    assert_select "td", text: other_customer.name, count: 0
  end

  test "should not allow access to other user's appointment" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)
    other_appointment = create_test_appointment(other_customer)

    get edit_appointment_url(other_appointment)
    assert_response :not_found
  end

  test "should not allow updating other user's appointment" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)
    other_appointment = create_test_appointment(other_customer)

    patch appointment_url(other_appointment), params: {
      appointment: { duration: 120 }
    }
    assert_response :not_found
  end

  test "should not allow deleting other user's appointment" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)
    other_appointment = create_test_appointment(other_customer)

    delete appointment_url(other_appointment)
    assert_response :not_found
  end
end
