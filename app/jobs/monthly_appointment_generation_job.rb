class MonthlyAppointmentGenerationJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting monthly appointment generation for #{Date.current.strftime('%B %Y')}"

    # Get target month (3 months from now)
    target_date = 3.months.from_now.to_date
    target_month_start = target_date.beginning_of_month
    target_month_end = target_date.end_of_month

    Rails.logger.info "Generating appointments for: #{target_month_start.strftime('%B %Y')}"

    total_created = 0
    total_errors = 0

    User.joins(:customers).distinct.find_each do |user|
      user_created, user_errors = generate_appointments_for_user(user, target_month_start, target_month_end)
      total_created += user_created
      total_errors += user_errors
    end

    Rails.logger.info "Monthly appointment generation completed: #{total_created} created, #{total_errors} errors"

    # Schedule the next month's generation
    schedule_next_month_generation
  end

  private

  def generate_appointments_for_user(user, month_start, month_end)
    Rails.logger.info "Processing user: #{user.email}"

    created_count = 0
    error_count = 0

    # Get active customers with regular patterns
    active_customers = user.customers.active

    active_customers.each do |customer|
      begin
        customer_appointments = generate_customer_appointments(customer, month_start, month_end)
        created_count += customer_appointments[:created]
        error_count += customer_appointments[:errors]

        Rails.logger.info "Customer #{customer.name}: #{customer_appointments[:created]} appointments created"
      rescue => e
        Rails.logger.error "Error generating appointments for customer #{customer.name}: #{e.message}"
        error_count += 1
      end
    end

    [ created_count, error_count ]
  end

  def generate_customer_appointments(customer, month_start, month_end)
    # Look at the customer's appointment patterns from the last 2 months
    pattern_start = 2.months.ago.beginning_of_month
    pattern_end = Date.current.end_of_month

    recent_appointments = customer.appointments
                                  .where(scheduled_at: pattern_start..pattern_end)
                                  .where(status: [ "scheduled", "completed" ])
                                  .order(:scheduled_at)

    return { created: 0, errors: 0 } if recent_appointments.empty?

    # Detect patterns: same day of week, same time, same duration
    patterns = detect_appointment_patterns(recent_appointments)

    return { created: 0, errors: 0 } if patterns.empty?

    # Generate appointments based on detected patterns
    created_count = 0
    error_count = 0

    patterns.each do |pattern|
      appointments_created = create_appointments_from_pattern(customer, pattern, month_start, month_end)
      created_count += appointments_created[:created]
      error_count += appointments_created[:errors]
    end

    { created: created_count, errors: error_count }
  end

  def detect_appointment_patterns(appointments)
    patterns = []

    # Group by day of week and time
    grouped = appointments.group_by do |apt|
      {
        wday: apt.scheduled_at.wday,
        hour: apt.scheduled_at.hour,
        minute: apt.scheduled_at.minute,
        duration: apt.duration
      }
    end

    # Only consider patterns that occur at least 3 times in the analyzed period
    grouped.each do |pattern_key, pattern_appointments|
      if pattern_appointments.count >= 3
        patterns << {
          wday: pattern_key[:wday],
          hour: pattern_key[:hour],
          minute: pattern_key[:minute],
          duration: pattern_key[:duration],
          frequency: pattern_appointments.count
        }
      end
    end

    patterns
  end

  def create_appointments_from_pattern(customer, pattern, month_start, month_end)
    created_count = 0
    error_count = 0

    # Find all dates in the target month that match the pattern's day of week
    current_date = month_start

    while current_date <= month_end
      if current_date.wday == pattern[:wday]
        appointment_time = Time.zone.local(
          current_date.year,
          current_date.month,
          current_date.day,
          pattern[:hour],
          pattern[:minute]
        )

        # Check if appointment already exists
        unless appointment_exists?(customer, appointment_time)
          # Check for conflicts with existing appointments
          unless appointment_conflict_exists?(customer, appointment_time, pattern[:duration])
            appointment = create_appointment(customer, appointment_time, pattern[:duration])

            if appointment.persisted?
              created_count += 1
              Rails.logger.debug "Created appointment: #{customer.name} - #{appointment_time}"
            else
              error_count += 1
              Rails.logger.warn "Failed to create appointment: #{appointment.errors.full_messages.join(', ')}"
            end
          else
            Rails.logger.debug "Skipped #{customer.name} - #{appointment_time} (conflict)"
          end
        else
          Rails.logger.debug "Skipped #{customer.name} - #{appointment_time} (already exists)"
        end
      end

      current_date += 1.day
    end

    { created: created_count, errors: error_count }
  end

  def appointment_exists?(customer, appointment_time)
    customer.appointments
            .where(scheduled_at: appointment_time)
            .exists?
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

  def create_appointment(customer, appointment_time, duration)
    Appointment.create(
      customer: customer,
      scheduled_at: appointment_time,
      duration: duration,
      status: "scheduled",
      notes: "Auto-gerado em #{Date.current.strftime('%d/%m/%Y')}"
      # Important: google_event_id is nil by default, so no calendar sync
    )
  end

  def schedule_next_month_generation
    # Schedule for the 1st of next month at 6 AM
    next_month_first = Date.current.next_month.beginning_of_month
    scheduled_time = next_month_first.beginning_of_day + 6.hours

    Rails.logger.info "Scheduling next monthly appointment generation for: #{scheduled_time}"

    MonthlyAppointmentGenerationJob.set(wait_until: scheduled_time).perform_later
  end
end
