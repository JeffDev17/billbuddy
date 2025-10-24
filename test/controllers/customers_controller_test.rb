require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @customer = create_test_customer(@user)
    sign_in @user
  end

  test "should get index" do
    get customers_url
    assert_response :success
    assert_select "h1", text: /Clientes/
  end

  test "should get new" do
    get new_customer_url
    assert_response :success
  end

  test "should create customer" do
    assert_difference("Customer.count") do
      post customers_url, params: {
        customer: {
          name: "New Customer",
          email: "new@example.com",
          phone: "+5511999999999",
          status: "active",
          plan_type: "credit"
        }
      }
    end

    assert_redirected_to customer_url(Customer.last)
    assert_equal "New Customer", Customer.last.name
  end

  test "should not create customer with invalid attributes" do
    assert_no_difference("Customer.count") do
      post customers_url, params: {
        customer: {
          name: "",
          email: "invalid_email",
          phone: "invalid_phone"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show customer" do
    get customer_url(@customer)
    assert_response :success
    assert_select "h1", text: @customer.name
  end

  test "should get edit" do
    get edit_customer_url(@customer)
    assert_response :success
  end

  test "should update customer" do
    patch customer_url(@customer), params: {
      customer: {
        name: "Updated Customer",
        email: "updated@example.com"
      }
    }

    assert_redirected_to customer_url(@customer)
    @customer.reload
    assert_equal "Updated Customer", @customer.name
    assert_equal "updated@example.com", @customer.email
  end

  test "should not update customer with invalid attributes" do
    patch customer_url(@customer), params: {
      customer: {
        name: "",
        email: "invalid_email"
      }
    }

    assert_response :unprocessable_entity
    @customer.reload
    assert_not_equal "", @customer.name
  end

  test "should destroy customer" do
    assert_difference("Customer.count", -1) do
      delete customer_url(@customer)
    end

    assert_redirected_to customers_url
  end

  test "should search customers by name" do
    customer2 = create_test_customer(@user, name: "Another Customer")

    get customers_url, params: { search: "Another" }
    assert_response :success
    assert_select "td", text: "Another Customer"
  end

  test "should filter customers by status" do
    @customer.update!(status: "inactive")

    get customers_url, params: { status: "inactive" }
    assert_response :success
    assert_select "td", text: "Another Customer"
  end

  test "should filter customers by plan type" do
    @customer.update!(plan_type: "subscription")

    get customers_url, params: { plan_type: "subscription" }
    assert_response :success
    assert_select "td", text: @customer.name
  end

  test "should debit hours for customer" do
    credit = create_test_customer_credit(@customer, remaining_hours: 5)

    post debit_hours_customer_url(@customer), params: {
      hours: 2,
      description: "Test debit"
    }

    assert_redirected_to customer_url(@customer)
    credit.reload
    assert_equal 3, credit.remaining_hours
  end

  test "should not debit more hours than available" do
    credit = create_test_customer_credit(@customer, remaining_hours: 1)

    post debit_hours_customer_url(@customer), params: {
      hours: 5,
      description: "Test debit"
    }

    assert_response :unprocessable_entity
    credit.reload
    assert_equal 1, credit.remaining_hours
  end

  test "should notify customer via WhatsApp" do
    mock_whatsapp_api_success do
      post notify_whatsapp_customer_url(@customer), params: {
        message: "Test message"
      }

      assert_redirected_to customer_url(@customer)
    end
  end

  test "should handle WhatsApp notification failure" do
    mock_whatsapp_api_failure do
      post notify_whatsapp_customer_url(@customer), params: {
        message: "Test message"
      }

      assert_response :unprocessable_entity
    end
  end

  test "should send payment reminder" do
    mock_whatsapp_api_success do
      post send_payment_reminder_customer_url(@customer), params: {
        message: "Payment reminder"
      }

      assert_redirected_to customer_url(@customer)
    end
  end

  test "should sync appointments for customer" do
    appointment = create_test_appointment(@customer)

    post sync_appointments_customer_url(@customer)
    assert_redirected_to customer_url(@customer)
  end

  test "should sync upcoming appointments for customer" do
    appointment = create_test_appointment(@customer, scheduled_at: 1.day.from_now)

    post sync_upcoming_appointments_customer_url(@customer)
    assert_redirected_to customer_url(@customer)
  end

  test "should get payment reminder form" do
    get payment_reminder_form_customer_url(@customer)
    assert_response :success
  end

  test "should export customers to CSV" do
    get export_csv_customers_url
    assert_response :success
    assert_equal "text/csv", response.content_type
  end

  test "should get CSV import template" do
    get download_template_customers_url
    assert_response :success
    assert_equal "text/csv", response.content_type
  end

  test "should get bulk message form" do
    get bulk_message_form_customers_url
    assert_response :success
  end

  test "should send bulk message" do
    customer2 = create_test_customer(@user, phone: "+5511888888888")

    mock_whatsapp_api_success do
      post send_bulk_message_customers_url, params: {
        customer_ids: [ @customer.id, customer2.id ],
        message: "Bulk test message",
        message_type: "custom"
      }

      assert_redirected_to customers_url
    end
  end

  test "should require authentication" do
    sign_out @user

    get customers_url
    assert_redirected_to new_user_session_url
  end

  test "should only show user's own customers" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)

    get customers_url
    assert_response :success
    assert_select "td", text: @customer.name
    assert_select "td", text: other_customer.name, count: 0
  end

  test "should not allow access to other user's customer" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)

    get customer_url(other_customer)
    assert_response :not_found
  end

  test "should not allow updating other user's customer" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)

    patch customer_url(other_customer), params: {
      customer: { name: "Hacked" }
    }
    assert_response :not_found
  end

  test "should not allow deleting other user's customer" do
    other_user = create_test_user(email: "other@example.com")
    other_customer = create_test_customer(other_user)

    delete customer_url(other_customer)
    assert_response :not_found
  end
end
