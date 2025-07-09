module UserScoped
  extend ActiveSupport::Concern

  private

  def current_user_customers
    @current_user_customers ||= current_user.customers
  end

  def find_customer(id)
    current_user_customers.find(id)
  end

  def find_customer_appointment(appointment_id)
    Appointment.joins(:customer).where(customers: { user_id: current_user.id }).find(appointment_id)
  end

  def find_customer_payment(customer_id, payment_id)
    customer = find_customer(customer_id)
    customer.payments.find(payment_id)
  end

  def user_scoped_appointments
    @user_scoped_appointments ||= Appointment.joins(:customer).where(customers: { user_id: current_user.id }).includes(:customer)
  end

  def user_scoped_payments
    @user_scoped_payments ||= Payment.joins(:customer).where(customers: { user_id: current_user.id }).includes(:customer)
  end
end
