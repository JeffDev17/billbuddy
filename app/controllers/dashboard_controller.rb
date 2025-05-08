class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @customers_count = current_user.customers.count
    @active_customers = current_user.customers.where(status: 'active').count
    @upcoming_appointments = Appointment.joins(:customer)
                                        .where(customers: { user_id: current_user.id })
                                        .where('scheduled_at > ?', Time.current)
                                        .where(status: 'scheduled')
                                        .order(scheduled_at: :asc)
                                        .limit(5)
  end
end