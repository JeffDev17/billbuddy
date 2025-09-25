class CustomerSchedulesController < ApplicationController
  include UserScoped

  before_action :authenticate_user!
  before_action :set_customer_schedule, only: [ :update, :destroy ]

  def create
    @customer = current_user_customers.find(params[:customer_id])
    @schedule = @customer.customer_schedules.build(schedule_params)
    @schedule.enabled = true

    if @schedule.save
      render json: { success: true, schedule: @schedule }
    else
      render json: { success: false, error: @schedule.errors.full_messages.join(", ") }
    end
  end

  def destroy
    if @customer_schedule.destroy
      render json: { success: true }
    else
      render json: { success: false, error: "Erro ao remover hor\u00E1rio" }
    end
  end

  def update
    if @customer_schedule.update(schedule_params)
      render json: { success: true, schedule: @customer_schedule }
    else
      render json: { success: false, error: @customer_schedule.errors.full_messages.join(", ") }
    end
  end

  private

  def set_customer_schedule
    @customer_schedule = CustomerSchedule.joins(:customer)
                                        .where(customers: { user_id: current_user.id })
                                        .find(params[:id])
  end

  def schedule_params
    params.permit(:day_of_week, :start_time, :duration, :enabled)
  end
end
