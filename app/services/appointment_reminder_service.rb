class AppointmentReminderService
  def self.send_upcoming_reminders(user = nil)
    new(user).send_upcoming_reminders
  end

  def self.preview_upcoming_reminders(user = nil)
    new(user).preview_upcoming_reminders
  end

  def initialize(user = nil)
    @user = user || User.first
  end

  def send_upcoming_reminders
    return unless reminders_enabled?

    eligible_appointments.each do |appointment|
      send_reminder_for(appointment)
    end
  end

  def preview_upcoming_reminders
    appointments = eligible_appointments

    {
      count: appointments.count,
      appointments: appointments.map { |apt| preview_details(apt) }
    }
  end

  def send_reminder_for(appointment, force: false)
    return unless force || appointment.needs_reminder?

    send_whatsapp_message(appointment)
    mark_reminder_sent(appointment)
  rescue StandardError => e
    handle_error(appointment, e)
  end

  private

  def reminders_enabled?
    @user&.appointment_reminders_enabled == true
  end

  def eligible_appointments
    Appointment.joins(customer: :user)
      .where(users: { id: @user.id })
      .where(status: "scheduled")
      .where(reminder_sent_at: nil)
      .where("scheduled_at > ?", Time.current)
      .where("scheduled_at <= ?", 30.minutes.from_now)
      .includes(:customer)
      .where.not(customers: { phone: nil })
  end

  def send_whatsapp_message(appointment)
    # TODO: WhatsApp temporariamente desativado
    return true

    formatted_phone = format_phone(appointment.customer.phone)
    message = build_message(appointment)

    WhatsappApiService.send_message(formatted_phone, message)
  end

  def format_phone(phone)
    PhoneFormatterService.format(phone)
  end

  def build_message(appointment)
    <<~MESSAGE
      Olá #{appointment.customer.name}!

      Lembrete: Seu agendamento está marcado para #{format_time(appointment.scheduled_at)}.

      📅 Data: #{format_date(appointment.scheduled_at)}
      ⏱️ Duração: #{format_duration(appointment.duration)}

      Nos vemos em breve!
    MESSAGE
  end

  def format_time(datetime)
    datetime.in_time_zone.strftime("%H:%M")
  end

  def format_date(datetime)
    datetime.in_time_zone.strftime("%d/%m/%Y")
  end

  def format_duration(duration)
    hours = duration.to_i
    minutes = ((duration % 1) * 60).to_i

    return "#{hours}h" if minutes.zero?
    "#{hours}h #{minutes}min"
  end

  def mark_reminder_sent(appointment)
    appointment.update!(reminder_sent_at: Time.current)
  end

  def handle_error(appointment, error)
    log_error(appointment, error)
    save_failed_notification(appointment, error)
  end

  def log_error(appointment, error)
    Rails.logger.error(
      "Appointment reminder failed for appointment #{appointment.id}: #{error.message}"
    )
  end

  def save_failed_notification(appointment, error)
    FailedNotification.create!(
      customer: appointment.customer,
      error_message: error.message,
      notification_type: "appointment_reminder"
    )
  end

  def preview_details(appointment)
    {
      id: appointment.id,
      customer_name: appointment.customer.name,
      customer_phone: appointment.customer.phone,
      scheduled_at: appointment.scheduled_at,
      time_until: time_until_appointment(appointment),
      message: build_message(appointment)
    }
  end

  def time_until_appointment(appointment)
    minutes = ((appointment.scheduled_at - Time.current) / 60).round
    "#{minutes} minutes"
  end
end
