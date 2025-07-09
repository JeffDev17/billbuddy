class CalendarDataService
  def initialize(user)
    @user = user
  end

  def appointments_for_date(date)
    current_user_appointments.where(
      scheduled_at: date.beginning_of_day..date.end_of_day
    ).includes(:customer)
     .order(:scheduled_at)
  end

  def appointment_to_event_object(appointment)
    customer = appointment.customer

    OpenStruct.new(
      id: appointment.id,
      summary: "#{customer.name} - #{appointment.status.humanize}",
      start: OpenStruct.new(
        date_time: appointment.scheduled_at,
        time_zone: "America/Sao_Paulo"
      ),
      end: OpenStruct.new(
        date_time: appointment.scheduled_at + appointment.duration.hours,
        time_zone: "America/Sao_Paulo"
      ),
      description: build_appointment_description(appointment),
      status: appointment.status,
      customer_name: customer.name,
      customer_phone: customer.phone,
      appointment_id: appointment.id,
      duration: appointment.duration,
      notes: appointment.notes,
      google_event_id: appointment.google_event_id,
      is_synced: appointment.google_event_id.present?,
      # Properties required by the view
      billbuddy_event: true,
      customer: customer,
      appointment: appointment,
      synced_to_calendar: appointment.google_event_id.present?
    )
  end

  def authorization_unavailable?
    !@user&.google_calendar_authorized?
  end

  private

  def current_user_appointments
    @current_user_appointments ||= Appointment.joins(:customer).where(customers: { user_id: @user.id })
  end

  def build_appointment_description(appointment)
    customer = appointment.customer

    description = "Cliente: #{customer.name}\n"
    description += "Telefone: #{customer.phone}\n" if customer.phone.present?
    description += "Email: #{customer.email}\n" if customer.email.present?
    description += "Duração: #{appointment.duration} hora(s)\n"
    description += "Status: #{appointment.status.humanize}\n"
    description += "Notas: #{appointment.notes}\n" if appointment.notes.present?
    description += "Criado em: #{appointment.created_at.strftime('%d/%m/%Y %H:%M')}\n"
    description += "Atualizado em: #{appointment.updated_at.strftime('%d/%m/%Y %H:%M')}\n"
    description
  end
end
