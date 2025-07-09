# Service to handle appointment completion with custom dates and credit management
class AppointmentCompletionService
  def initialize(user)
    @user = user
  end

  def mark_as_completed(appointment, completion_date = nil)
    return failure_result("Compromisso não encontrado") unless appointment
    return failure_result("Compromisso já foi concluído") if appointment.completed?

    completion_date ||= Date.current
    completion_datetime = completion_date.beginning_of_day + appointment.scheduled_at.hour.hours + appointment.scheduled_at.min.minutes

    ActiveRecord::Base.transaction do
      appointment.update!(
        status: "completed",
        completed_at: completion_datetime,
        notes: build_completion_notes(appointment, completion_date)
      )

      if appointment.customer.credit? && should_deduct_credits?(appointment)
        deduct_customer_credits(appointment)
      end

      earnings = calculate_appointment_earnings(appointment)

      success_result(appointment, earnings, completion_date)
    end
  rescue => e
    Rails.logger.error "Appointment completion error: #{e.message}"
    failure_result("Erro ao concluir compromisso: #{e.message}")
  end

  def bulk_mark_completed(appointment_ids, completion_date = nil)
    completion_date ||= Date.current
    completed_appointments = []
    errors = []
    total_earnings = 0

    appointment_ids.each do |appointment_id|
      appointment = find_user_appointment(appointment_id)

      if appointment
        result = mark_as_completed(appointment, completion_date)

        if result[:success]
          completed_appointments << result[:appointment]
          total_earnings += result[:earnings]
        else
          errors << "#{appointment.customer.name} (#{appointment.scheduled_at.strftime('%H:%M')}): #{result[:message]}"
        end
      else
        errors << "Compromisso ##{appointment_id} não encontrado"
      end
    end

    {
      success: completed_appointments.any?,
      completed_count: completed_appointments.count,
      total_earnings: total_earnings,
      completion_date: completion_date,
      errors: errors
    }
  end

  def get_daily_completion_data(date)
    appointments = user_appointments_for_date(date)
    completed_appointments = appointments.completed

    {
      total_appointments: appointments.count,
      completed_appointments: completed_appointments.count,
      pending_appointments: appointments.scheduled.count,
      total_earnings: calculate_daily_earnings(completed_appointments),
      appointments_by_status: appointments.group(:status).count
    }
  end

  def get_completable_appointments(date)
    user_appointments_for_date(date).scheduled.includes(:customer).order(:scheduled_at)
  end

  private

  def find_user_appointment(appointment_id)
    Appointment.joins(:customer)
               .where(customers: { user_id: @user.id })
               .find_by(id: appointment_id)
  end

  def user_appointments_for_date(date)
    base_scope = Appointment.joins(:customer)
                          .where(customers: { user_id: @user.id })
                          .includes(:customer)

    # For completed appointments, use completed_at
    completed = base_scope.where(status: "completed")
                         .where(completed_at: date.beginning_of_day..date.end_of_day)

    # For scheduled appointments, use scheduled_at
    scheduled = base_scope.where(status: "scheduled")
                         .where(scheduled_at: date.beginning_of_day..date.end_of_day)

    # Combine both scopes
    Appointment.where(id: completed.select(:id).or(scheduled.select(:id)))
  end

  def should_deduct_credits?(appointment)
    appointment.customer.credit? && appointment.customer.total_remaining_hours > 0
  end

  def deduct_customer_credits(appointment)
    hours_to_deduct = appointment.duration
    customer = appointment.customer

    remaining_hours = hours_to_deduct
    credits = customer.customer_credits.where("remaining_hours > 0").order(purchase_date: :asc)

    credits.each do |credit|
      break if remaining_hours <= 0

      if credit.remaining_hours >= remaining_hours
        credit.update!(remaining_hours: credit.remaining_hours - remaining_hours)
        remaining_hours = 0
      else
        remaining_hours -= credit.remaining_hours
        credit.update!(remaining_hours: 0)
      end
    end

    if remaining_hours > 0
      Rails.logger.warn "Insufficient credits for appointment #{appointment.id}. #{remaining_hours} hours could not be deducted."
    end
  end

  def calculate_appointment_earnings(appointment)
    appointment.duration * appointment.customer.effective_hourly_rate
  end

  def calculate_daily_earnings(completed_appointments)
    completed_appointments.sum do |appointment|
      calculate_appointment_earnings(appointment)
    end
  end

  def build_completion_notes(appointment, completion_date)
    existing_notes = appointment.notes.to_s
    completion_note = "Concluído em #{completion_date.strftime('%d/%m/%Y')}"

    if existing_notes.present?
      "#{existing_notes}\n#{completion_note}"
    else
      completion_note
    end
  end

  def success_result(appointment, earnings, completion_date)
    {
      success: true,
      appointment: appointment,
      earnings: earnings,
      completion_date: completion_date,
      message: "Compromisso marcado como concluído"
    }
  end

  def failure_result(message)
    {
      success: false,
      message: message
    }
  end
end
