# Smart Google Calendar Sync Service
#
# This service creates efficient recurring events based on customer_schedules
# Groups same times across different days to minimize API calls
# Focuses on monthly sync with clear end dates
class SmartGoogleCalendarSyncService
  include GoogleCalendarClient

  def initialize(user)
    @user = user
    @service = setup_calendar_service(user)
  end

  # Main sync method - sync current month for all customers with schedules
  def sync_current_month
    return { success: false, message: "Google Calendar not authorized" } unless @service

    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    sync_month(start_date, end_date)
  end

  # Sync specific month
  def sync_month(start_date, end_date)
    return { success: false, message: "Google Calendar not authorized" } unless @service

    customers_with_schedules = @user.customers.active.joins(:customer_schedules)
                                   .where(customer_schedules: { enabled: true })
                                   .includes(:customer_schedules)
                                   .distinct

    return { success: false, message: "No customers with regular schedules found" } if customers_with_schedules.empty?

    results = {
      success: true,
      customers_processed: 0,
      events_created: 0,
      api_calls_saved: 0,
      errors: []
    }

    customers_with_schedules.each do |customer|
      customer_result = sync_customer_for_month(customer, start_date, end_date)

      results[:customers_processed] += 1 if customer_result[:success]
      results[:events_created] += customer_result[:events_created] || 0
      results[:api_calls_saved] += customer_result[:api_calls_saved] || 0
      results[:errors].concat(customer_result[:errors] || [])
    end

    results[:message] = build_success_message(results)
    results
  end

  # Sync next month for planning ahead
  def sync_next_month
    start_date = Date.current.next_month.beginning_of_month
    end_date = Date.current.next_month.end_of_month

    sync_month(start_date, end_date)
  end

  private

  def sync_customer_for_month(customer, start_date, end_date)
    schedules = customer.customer_schedules.enabled.order(:start_time)

    return { success: false, errors: [ "No schedules for #{customer.name}" ] } if schedules.empty?

    # Group schedules by time and duration to create efficient recurring events
    grouped_schedules = group_schedules_by_time_and_duration(schedules)

    results = {
      success: true,
      events_created: 0,
      api_calls_saved: 0,
      errors: []
    }

    grouped_schedules.each do |time_group, schedule_list|
      group_result = create_recurring_event_for_schedule_group(
        customer,
        schedule_list,
        start_date,
        end_date
      )

      if group_result[:success]
        results[:events_created] += 1
        # Calculate API calls saved (would have been one call per occurrence)
        total_occurrences = calculate_total_occurrences(schedule_list, start_date, end_date)
        results[:api_calls_saved] += [ total_occurrences - 1, 0 ].max
      else
        results[:errors].concat(group_result[:errors] || [])
      end
    end

    results
  rescue => e
    Rails.logger.error "Error syncing customer #{customer.name}: #{e.message}"
    { success: false, errors: [ "Error syncing #{customer.name}: #{e.message}" ] }
  end

  def group_schedules_by_time_and_duration(schedules)
    schedules.group_by do |schedule|
      {
        time: schedule.start_time.strftime("%H:%M"),
        duration: schedule.duration
      }
    end
  end

  def create_recurring_event_for_schedule_group(customer, schedules, start_date, end_date)
    first_schedule = schedules.first

    # Get all days of week for this time/duration group
    days_of_week = schedules.map(&:day_of_week).sort

    # Create the recurring event
    event = build_recurring_event(
      customer,
      first_schedule,
      days_of_week,
      start_date,
      end_date
    )

    begin
      google_event = @service.insert_event("primary", event)

      # Mark related appointments as synced (if they exist)
      mark_appointments_as_synced(customer, schedules, google_event.id, start_date, end_date)

      { success: true, google_event_id: google_event.id }
    rescue Google::Apis::Error => e
      Rails.logger.error "Google Calendar API error: #{e.message}"
      { success: false, errors: [ "Failed to create event for #{customer.name}: #{e.message}" ] }
    end
  end

  def build_recurring_event(customer, schedule, days_of_week, start_date, end_date)
    # Find the first occurrence of this schedule in the month
    first_occurrence = find_first_occurrence(schedule, days_of_week, start_date)

    start_time = Time.zone.local(
      first_occurrence.year,
      first_occurrence.month,
      first_occurrence.day,
      schedule.start_time.hour,
      schedule.start_time.min
    )

    end_time = start_time + schedule.duration.hours

    Google::Apis::CalendarV3::Event.new(
      summary: "#{customer.name} (Regular Schedule)",
      description: build_event_description(customer, schedule, days_of_week),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: "America/Sao_Paulo"
      ),
      recurrence: [ build_recurrence_rule(days_of_week, end_date) ],
      attendees: [], # No email invitations during testing
      reminders: { use_default: true },
      extended_properties: {
        private: {
          billbuddy_customer_id: customer.id.to_s,
          billbuddy_sync_month: start_date.strftime("%Y_%m"),
          billbuddy_schedule_ids: days_of_week.join(","),
          duration: schedule.duration.to_s
        }
      }
    )
  end

  def find_first_occurrence(schedule, days_of_week, start_date)
    # Find the first day in the month that matches one of our days of week
    current_date = start_date

    while current_date <= start_date.end_of_month
      return current_date if days_of_week.include?(current_date.wday)
      current_date += 1.day
    end

    start_date # fallback
  end

  def build_recurrence_rule(days_of_week, end_date)
    # Convert Ruby wday (0=Sunday) to RFC format
    rfc_days = days_of_week.map { |wday| convert_wday_to_rfc(wday) }

    rrule = "RRULE:FREQ=WEEKLY"
    rrule += ";BYDAY=#{rfc_days.join(',')}" if rfc_days.any?
    rrule += ";UNTIL=#{end_date.strftime('%Y%m%d')}T235959Z"

    rrule
  end

  def convert_wday_to_rfc(wday)
    %w[SU MO TU WE TH FR SA][wday]
  end

  def build_event_description(customer, schedule, days_of_week)
    day_names = days_of_week.map { |wday| Date::DAYNAMES[wday] }

    description = []
    description << "🔄 EVENTO RECORRENTE - #{day_names.join(', ')}"
    description << "⏰ #{schedule.start_time.strftime('%H:%M')} (#{schedule.duration}h)"
    description << ""
    description << "👤 Cliente: #{customer.name}"
    description << "📧 Email: #{customer.email}" if customer.email.present?
    description << "📱 Telefone: #{customer.phone}" if customer.phone.present?
    description << ""
    description << "📅 Criado pelo BillBuddy - Smart Sync"
    description << "🚫 Durante testes - sem convites por email"

    description.join("\n")
  end

  def mark_appointments_as_synced(customer, schedules, google_event_id, start_date, end_date)
    # Find appointments that match these schedules in the given period
    schedule_day_times = schedules.map do |schedule|
      {
        wday: schedule.day_of_week,
        hour: schedule.start_time.hour,
        minute: schedule.start_time.min,
        duration: schedule.duration
      }
    end

    appointments = customer.appointments
                          .where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
                          .where(google_event_id: nil) # Only unsynced appointments

    appointments.each do |appointment|
      appointment_time = appointment.scheduled_at

      matching_schedule = schedule_day_times.find do |schedule_time|
        appointment_time.wday == schedule_time[:wday] &&
        appointment_time.hour == schedule_time[:hour] &&
        appointment_time.min == schedule_time[:minute] &&
        appointment.duration == schedule_time[:duration]
      end

      if matching_schedule
        appointment.update!(
          google_event_id: google_event_id,
          is_recurring_event: true
        )
      end
    end
  end

  def calculate_total_occurrences(schedules, start_date, end_date)
    total = 0
    current_date = start_date

    while current_date <= end_date
      schedules.each do |schedule|
        total += 1 if current_date.wday == schedule.day_of_week
      end
      current_date += 1.day
    end

    total
  end

  def build_success_message(results)
    message = "✅ Sync completed! "
    message += "#{results[:customers_processed]} customers processed, "
    message += "#{results[:events_created]} recurring events created"

    if results[:api_calls_saved] > 0
      message += " (saved #{results[:api_calls_saved]} API calls)"
    end

    if results[:errors].any?
      message += ". #{results[:errors].count} errors occurred."
    end

    message
  end
end
