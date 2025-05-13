class DashboardController < ApplicationController
  def index
    @customers_count = Customer.count
    @active_customers = Customer.where(status: 'active').count
    @upcoming_appointments = Appointment.order(scheduled_at: :asc).limit(5)
  end
end