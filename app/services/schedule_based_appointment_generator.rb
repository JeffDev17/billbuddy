# Simple appointment generation service based on customer regular schedules
class ScheduleBasedAppointmentGenerator
  def initialize(user = nil)
    @user = user
  end

  # Generate appointments for a date range based on customer schedules
  def generate_appointments(start_date, end_date, options = {})
    Rails.logger.info "Generating schedule-based appointments from #{start_date} to #{end_date}"

    results = {
      appointments_created: 0,
      customers_processed: 0,
      errors: [],
      preview: options[:preview_only] == true,
      details: [],
      customers: {}  # Add this for view compatibility
    }

    target_customers = @user ? @user.customers.active : Customer.active

    # Only process customers with schedules
    customers_with_schedules = target_customers.joins(:customer_schedules)
                                               .where(customer_schedules: { enabled: true })
                                               .distinct

    customers_with_schedules.find_each do |customer|
      begin
        customer_result = generate_for_customer(customer, start_date, end_date, options)
        results[:appointments_created] += customer_result[:created]
        results[:customers_processed] += 1
        patterns_data = customer_result[:appointments]&.map { |apt|
          {
            day_of_week: apt[:scheduled_at].wday,
            time: apt[:scheduled_at].strftime("%H:%M"),
            duration: apt[:duration],
            count: 1  # Each appointment represents one pattern occurrence
          }
        } || []

        results[:details] << {
          customer_id: customer.id,  # Add customer ID for individual actions
          customer_name: customer.name,
          customer: customer.name,  # Add for view compatibility
          appointments_created: customer_result[:created],
          created: customer_result[:created],  # Add for view compatibility
          appointments: customer_result[:appointments] || [],
          patterns: patterns_data
        }

        # Add to customers hash for view compatibility
        results[:customers][customer.name] = {
          appointments: customer_result[:appointments],
          patterns_count: customer_result[:appointments].size
        }

        results[:errors].concat(customer_result[:errors])

        Rails.logger.info "Customer #{customer.name}: #{customer_result[:created]} appointments"
      rescue => e
        error_msg = "Error processing customer #{customer.name}: #{e.message}"
        results[:errors] << error_msg
        Rails.logger.error error_msg
      end
    end

    # Ensure required fields are never nil for view compatibility
    results[:details] ||= []
    results[:customers] ||= {}

    Rails.logger.info "Schedule-based generation completed: #{results[:customers_processed]} customers processed, #{results[:appointments_created]} appointments created"
    results
  end

  # Generate for next month only
  def generate_next_month(options = {})
    start_date = Date.current.next_month.beginning_of_month
    end_date = Date.current.next_month.end_of_month
    generate_appointments(start_date, end_date, options)
  end

  # Generate for specific customer
  def generate_for_customer(customer, start_date, end_date, options = {})
    results = {
      created: 0,
      errors: [],
      appointments: []
    }

    # Get customer's active schedules
    schedules = customer.customer_schedules.enabled

    return results if schedules.empty?

    current_date = start_date
    while current_date <= end_date
      day_of_week = current_date.wday

      # Find schedules for this day
      day_schedules = schedules.where(day_of_week: day_of_week)

      day_schedules.each do |schedule|
        appointment_time = schedule.appointment_time_for_date(current_date)

        next if appointment_time.nil?
        next if appointment_time <= Time.current  # Skip past appointments

        # Check if appointment already exists
        unless appointment_exists?(customer, appointment_time)
          # Check for conflicts
          unless appointment_conflict_exists?(customer, appointment_time, schedule.duration)

            appointment_details = {
              customer_name: customer.name,
              scheduled_at: appointment_time,
              duration: schedule.duration,
              day_name: schedule.day_name,
              schedule_id: schedule.id
            }

            if options[:preview_only]
              results[:appointments] << appointment_details
              results[:created] += 1
            else
              appointment = create_appointment(customer, appointment_time, schedule)

              if appointment.persisted?
                results[:appointments] << appointment_details.merge(id: appointment.id)
                results[:created] += 1
                Rails.logger.debug "Created: #{customer.name} - #{appointment_time.strftime('%d/%m/%Y %H:%M')}"
              else
                error_msg = "Failed to create appointment for #{customer.name} at #{appointment_time}: #{appointment.errors.full_messages.join(', ')}"
                results[:errors] << error_msg
                Rails.logger.warn error_msg
              end
            end
          else
            Rails.logger.debug "Skipped #{customer.name} - #{appointment_time.strftime('%d/%m/%Y %H:%M')} (conflict)"
          end
        else
          Rails.logger.debug "Skipped #{customer.name} - #{appointment_time.strftime('%d/%m/%Y %H:%M')} (exists)"
        end
      end

      current_date += 1.day
    end

    results
  end

  private

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

  def create_appointment(customer, appointment_time, schedule)
    Appointment.create(
      customer: customer,
      scheduled_at: appointment_time,
      duration: schedule.duration,
      status: "scheduled",
      notes: "Gerado automaticamente baseado em horário regular (#{schedule.day_name} #{schedule.formatted_time}) em #{Date.current.strftime('%d/%m/%Y')}"
    )
  end
end
