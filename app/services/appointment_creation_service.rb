# Service to handle appointment creation (single, recurring, and bulk)
class AppointmentCreationService
  MAX_APPOINTMENTS = 60
  DEFAULT_WEEKS = 12

  def initialize(user)
    @user = user
  end

  def create_single(appointment_params, sync_to_calendar: true)
    appointment = Appointment.new(appointment_params.merge(status: "scheduled"))

    if appointment.save
      sync_appointment_to_calendar(appointment) if sync_to_calendar
      { success: true, appointment: appointment }
    else
      { success: false, errors: appointment.errors.full_messages }
    end
  end

  def create_recurring(appointment_params, recurring_params, sync_to_calendar: true)
    base_appointment_params = appointment_params
    scheduled_at = DateTime.parse(base_appointment_params[:scheduled_at])
    recurring_days = recurring_params[:days].map(&:to_i).sort

    end_date = calculate_end_date(recurring_params[:until], recurring_params[:no_end_date])

    created_appointments = []
    errors = []
    current_week_start = scheduled_at.to_date.beginning_of_week
    customer = Customer.find(base_appointment_params[:customer_id])

    week_count = 0
    max_weeks = ((end_date - current_week_start).to_i / 7.0).ceil

    while week_count < max_weeks && created_appointments.count < MAX_APPOINTMENTS
      week_start = current_week_start + (week_count * 7).days

      recurring_days.each do |day|
        # Calculate the date for this day of the week
        days_until_target = (day - week_start.wday) % 7
        appointment_date = week_start + days_until_target.days
        next if appointment_date > end_date

        appointment_time = Time.zone.parse("#{appointment_date.strftime('%Y-%m-%d')} #{scheduled_at.strftime('%H:%M:%S')}")
        next if appointment_time <= Time.current

        # Check for conflicts
        if appointment_conflict_exists?(customer, appointment_time, base_appointment_params[:duration])
          errors << "Conflito detectado em #{appointment_time.strftime('%d/%m/%Y %H:%M')}"
          next
        end

        appointment = create_appointment_for_date(base_appointment_params, appointment_time, sync_to_calendar)

        if appointment.persisted?
          created_appointments << appointment
        else
          errors << "Erro em #{appointment_time.strftime('%d/%m/%Y %H:%M')}: #{appointment.errors.full_messages.join(', ')}"
        end

        break if created_appointments.count >= MAX_APPOINTMENTS
      end

      week_count += 1
    end

    { success: created_appointments.any?, appointments: created_appointments, errors: errors }
  end

  def create_bulk(customers, start_date, end_date, recurring_days, time_slots, duration, sync_to_calendar: true)
    created_count = 0
    errors = []

    customers.each do |customer|
      time_slots.each do |time_slot|
        recurring_days.each do |day|
          current_date = start_date

          while current_date <= end_date
            if current_date.wday == day
              appointment_time = Time.zone.parse("#{current_date.strftime('%Y-%m-%d')} #{time_slot}")

              unless appointment_conflict_exists?(customer, appointment_time, duration)
                appointment_params = {
                  customer_id: customer.id,
                  scheduled_at: appointment_time,
                  duration: duration,
                  status: "scheduled"
                }

                appointment = Appointment.new(appointment_params)

                if appointment.save
                  sync_appointment_to_calendar(appointment) if sync_to_calendar
                  created_count += 1
                else
                  errors << "#{customer.name} - #{appointment_time.strftime('%d/%m/%Y %H:%M')}: #{appointment.errors.full_messages.join(', ')}"
                end
              else
                errors << "#{customer.name} - #{appointment_time.strftime('%d/%m/%Y %H:%M')}: Conflito de horário"
              end
            end

            current_date += 1.day
          end
        end
      end
    end

    { success: created_count, errors: errors }
  end

  private

  def calculate_end_date(until_param, no_end_date)
    if until_param.present? && no_end_date != "1"
      Date.parse(until_param)
    else
      Date.current + DEFAULT_WEEKS.weeks
    end
  end

  def appointment_conflict_exists?(customer, appointment_time, duration)
    duration_hours = duration.to_f
    end_time = appointment_time + duration_hours.hours

    customer.appointments.where(
      "(scheduled_at <= ? AND scheduled_at + (duration || ' hours')::interval > ?) OR " \
      "(scheduled_at < ? AND scheduled_at + (duration || ' hours')::interval >= ?)",
      appointment_time, appointment_time, end_time, end_time
    ).exists?
  end

  def create_appointment_for_date(base_params, appointment_time, sync_to_calendar = true)
    appointment_params = base_params.merge(
      scheduled_at: appointment_time,
      status: "scheduled"
    )

    appointment = Appointment.create(appointment_params)
    sync_appointment_to_calendar(appointment) if sync_to_calendar && appointment.persisted?
    appointment
  end

  def sync_appointment_to_calendar(appointment)
    return unless @user.google_calendar_authorized?
    appointment.sync_to_calendar
  rescue => e
    Rails.logger.error "Failed to sync appointment #{appointment.id} to calendar: #{e.message}"
  end
end
