# app/controllers/appointments_controller.rb
class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: [:index, :new, :create]
  before_action :set_appointment, only: [:edit, :update, :destroy]

  def index
    @appointments = if @customer
                      @customer.appointments
                    else
                      Appointment.joins(:customer).where(customers: { user_id: current_user.id })
                    end

    # Aplicar filtros
    @appointments = @appointments.where(status: params[:status]) if params[:status].present?

    if params[:start_date].present?
      start_date = Date.parse(params[:start_date]).beginning_of_day
      @appointments = @appointments.where('scheduled_at >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.parse(params[:end_date]).end_of_day
      @appointments = @appointments.where('scheduled_at <= ?', end_date)
    end

    @appointments = @appointments.order(scheduled_at: :desc)
  end

  def new
    @appointment = if @customer
                     @customer.appointments.new(status: 'scheduled')
                   else
                     Appointment.new(status: 'scheduled')
                   end
  end

  def create
    @appointment = if @customer
                     @customer.appointments.new(appointment_params)
                   else
                     Appointment.new(appointment_params)
                   end

    if @appointment.save
      redirect_to appointments_path, notice: 'Compromisso criado com sucesso.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    old_status = @appointment.status

    if @appointment.update(appointment_params)
      # Se o status mudou para 'completed', atualizar os créditos do cliente
      if old_status != 'completed' && @appointment.status == 'completed'
        @appointment.send(:update_customer_credits)
      end

      redirect_to appointments_path, notice: 'Compromisso atualizado com sucesso.'
    else
      render :edit
    end
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_path, notice: 'Compromisso excluído com sucesso.'
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:customer_id]) if params[:customer_id]
  end

  def set_appointment
    @appointment = Appointment.joins(:customer).where(customers: { user_id: current_user.id }).find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(:customer_id, :scheduled_at, :duration, :status, :notes)
  end
end