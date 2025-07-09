class GoogleCalendarEventBuilder
  def self.individual(appointment)
    customer = appointment.customer
    start_time = appointment.scheduled_at
    end_time = start_time + appointment.duration.hours

    Google::Apis::CalendarV3::Event.new(
      summary: customer.name,
      description: build_event_description(appointment),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      attendees: build_attendees(customer),
      reminders: { use_default: true },
      extended_properties: {
        private: {
          billbuddy_appointment_id: appointment.id.to_s,
          customer_id: customer.id.to_s,
          duration: appointment.duration.to_s
        }
      }
    )
  end

  def self.recurring(appointments, pattern)
    first_appointment = appointments.sort_by(&:scheduled_at).first
    last_appointment = appointments.sort_by(&:scheduled_at).last
    customer = first_appointment.customer
    start_time = first_appointment.scheduled_at
    end_time = start_time + first_appointment.duration.hours

    Google::Apis::CalendarV3::Event.new(
      summary: "#{customer.name} (Recurring)",
      description: build_recurring_event_description(first_appointment, pattern),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      recurrence: [ build_recurrence_rule(pattern, last_appointment) ],
      attendees: build_attendees(customer),
      reminders: { use_default: true },
      extended_properties: {
        private: {
          billbuddy_recurring_series: "true",
          customer_id: customer.id.to_s,
          duration: first_appointment.duration.to_s,
          pattern_freq: pattern[:freq]
        }
      }
    )
  end

  def self.update_from_appointment(event, appointment)
    customer = appointment.customer
    start_time = appointment.scheduled_at
    end_time = start_time + appointment.duration.hours

    event.summary = customer.name
    event.description = build_event_description(appointment)
    event.start.date_time = start_time.iso8601
    event.end.date_time = end_time.iso8601
    event.attendees = build_attendees(customer)
  end

  private

  def self.build_event_description(appointment)
    customer = appointment.customer
    description = []

    description << "Cliente: #{customer.name}"
    description << "Email: #{customer.email}" if customer.email.present?
    description << "Telefone: #{customer.phone}" if customer.phone.present?
    description << "Duração: #{appointment.duration} hora(s)"

    if customer.credit?
      description << "Tipo: Crédito (#{customer.total_remaining_hours}h restantes)"
    elsif customer.subscription?
      description << "Tipo: Assinatura"
    end

    description << "Notas: #{appointment.notes}" if appointment.notes.present?
    description.join("\n")
  end

  def self.build_recurring_event_description(appointment, pattern)
    customer = appointment.customer
    description = []

    # Show pattern details
    if pattern[:byday].include?(",")
      days = pattern[:byday].split(",").map { |day| translate_weekday(day) }.join(", ")
      description << "🔄 SÉRIE RECORRENTE - #{pattern[:freq]} (#{days})"
    else
      day = translate_weekday(pattern[:byday])
      description << "🔄 SÉRIE RECORRENTE - #{pattern[:freq]} (#{day})"
    end

    description << ""
    description << "Cliente: #{customer.name}"
    description << "Email: #{customer.email}" if customer.email.present?
    description << "Telefone: #{customer.phone}" if customer.phone.present?
    description << "Duração: #{appointment.duration} hora(s)"

    if customer.credit?
      description << "Tipo: Crédito (#{customer.total_remaining_hours}h restantes)"
    elsif customer.subscription?
      description << "Tipo: Assinatura"
    end

    description << ""
    description << "⚠️ Esta é uma série recorrente criada pelo BillBuddy."
    description << "Para cancelar toda a série, delete este evento."
    description << "Para cancelar apenas uma aula, altere o status do compromisso no BillBuddy."

    description.join("\n")
  end

  def self.build_attendees(customer)
    # Temporarily disabled - no invites sent to customers
    []

    # To reactivate normal behavior (customers receive invites), uncomment this line:
    # customer.email.present? ? [ Google::Apis::CalendarV3::EventAttendee.new(email: customer.email) ] : []
  end

  def self.build_recurrence_rule(pattern, last_appointment)
    rrule = "RRULE:FREQ=#{pattern[:freq]}"
    rrule += ";INTERVAL=#{pattern[:interval]}" if pattern[:interval]
    rrule += ";BYDAY=#{pattern[:byday]}" if pattern[:byday]

    # Set end date for the recurrence (3 months max)
    until_date = [ last_appointment.scheduled_at.to_date, Date.current + 3.months ].min
    rrule += ";UNTIL=#{until_date.strftime('%Y%m%d')}T235959Z"

    rrule
  end

  def self.translate_weekday(weekday_code)
    {
      "SU" => "Domingo",
      "MO" => "Segunda",
      "TU" => "Ter\u00E7a",
      "WE" => "Quarta",
      "TH" => "Quinta",
      "FR" => "Sexta",
      "SA" => "S\u00E1bado"
    }[weekday_code] || weekday_code
  end
end
