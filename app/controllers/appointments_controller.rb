# app/controllers/appointments_controller.rb
class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: [ :index, :new, :create ]
  before_action :set_appointment, only: [ :edit, :update, :destroy ]

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
      @appointments = @appointments.where("scheduled_at >= ?", start_date)
    end

    if params[:end_date].present?
      end_date = Date.parse(params[:end_date]).end_of_day
      @appointments = @appointments.where("scheduled_at <= ?", end_date)
    end

    @appointments = @appointments.order(scheduled_at: :desc)
  end

  def new
    @appointment = if @customer
                     @customer.appointments.new(status: "scheduled")
    else
                     Appointment.new(status: "scheduled")
    end
  end

  def create
    if params[:is_recurring] == "1" && params[:recurring_days].present?
      # Handle recurring appointment creation
      created_appointments = create_recurring_appointments
      if created_appointments.any?
        message = "#{created_appointments.count} compromissos recorrentes criados com sucesso."
        message += " Use 'Sincronizar' no calendário para enviar ao Google Calendar." if current_user.google_calendar_authorized?

        redirect_to appointments_path, notice: message
      else
        @appointment = build_appointment
        render :new
      end
    else
      # Handle single appointment creation
      @appointment = build_appointment

      if @appointment.save
        redirect_to appointments_path, notice: "Compromisso criado com sucesso."
      else
        render :new
      end
    end
  end

  def edit
  end

  def update
    old_status = @appointment.status

    if @appointment.update(appointment_params)
      # Se o status mudou para 'completed', atualizar os créditos do cliente
      if old_status != "completed" && @appointment.status == "completed"
        @appointment.send(:update_customer_credits)
      end

      redirect_to appointments_path, notice: "Compromisso atualizado com sucesso."
    else
      render :edit
    end
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_path, notice: "Compromisso exclu\u00EDdo com sucesso."
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

  def build_appointment
    if @customer
      @customer.appointments.new(appointment_params)
    else
      Appointment.new(appointment_params)
    end
  end

  def create_recurring_appointments
    base_appointment_params = appointment_params
    scheduled_at = DateTime.parse(base_appointment_params[:scheduled_at])
    recurring_days = params[:recurring_days].map(&:to_i).sort

    # Set reasonable limits
    max_appointments = 60 # Limit to 60 appointments max
    default_weeks = 12 # Default to 12 weeks (3 months) instead of 6 months

    end_date = if params[:recurring_until].present? && params[:no_end_date] != "1"
                 Date.parse(params[:recurring_until])
    else
                 Date.current + default_weeks.weeks
    end

    created_appointments = []
    errors = []
    current_week_start = scheduled_at.to_date.beginning_of_week

    # Iterate week by week instead of day by day for efficiency
    week_count = 0
    max_weeks = ((end_date - current_week_start).to_i / 7.0).ceil

    while week_count < max_weeks && created_appointments.count < max_appointments
      week_start = current_week_start + (week_count * 7).days

      # Skip if this week is beyond our end date
      break if week_start > end_date

      # Create appointments for each selected day in this week
      recurring_days.each do |day_of_week|
        appointment_date = week_start + day_of_week.days

        # Skip if this specific date is beyond our end date or in the past
        next if appointment_date > end_date
        next if appointment_date < Date.current

        appointment_time = Time.zone.local(
          appointment_date.year,
          appointment_date.month,
          appointment_date.day,
          scheduled_at.hour,
          scheduled_at.min
        )

        appointment = if @customer
                       @customer.appointments.new(base_appointment_params.merge(scheduled_at: appointment_time))
        else
                       Appointment.new(base_appointment_params.merge(scheduled_at: appointment_time))
        end

        if appointment.save
          created_appointments << appointment
        else
          errors << "#{appointment_time.strftime('%d/%m/%Y')}: #{appointment.errors.full_messages.join(', ')}"
        end

        # Stop if we've reached the max limit
        break if created_appointments.count >= max_appointments
      end

      week_count += 1
    end

    # Set instance variable for error display
    if errors.any?
      @appointment = build_appointment
      @appointment.errors.add(:base, "Alguns compromissos não puderam ser criados:")
      errors.each { |error| @appointment.errors.add(:base, error) }
    end

    # Add warning if we hit the limit
    if created_appointments.count >= max_appointments
      @appointment ||= build_appointment
      @appointment.errors.add(:base, "Limite de #{max_appointments} compromissos atingido. Considere usar um período menor ou criar em lotes.")
    end

    created_appointments
  end
end
