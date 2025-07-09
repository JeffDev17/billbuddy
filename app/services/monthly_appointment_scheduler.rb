# Service to manage monthly appointment generation scheduling
class MonthlyAppointmentScheduler
  class << self
    def schedule_monthly_generation
      # Schedule for the 1st of next month at 6 AM
      next_month_first = Date.current.next_month.beginning_of_month
      scheduled_time = next_month_first.beginning_of_day + 6.hours

      Rails.logger.info "Scheduling monthly appointment generation for: #{scheduled_time}"

      MonthlyAppointmentGenerationJob.set(wait_until: scheduled_time).perform_later
    end

    def run_now_for_testing
      Rails.logger.info "Running monthly appointment generation immediately for testing"
      MonthlyAppointmentGenerationJob.perform_now
    end

    def run_for_specific_month(target_month, target_year)
      Rails.logger.info "Running appointment generation for specific month: #{target_month}/#{target_year}"

      target_date = Date.new(target_year, target_month, 1)
      month_start = target_date.beginning_of_month
      month_end = target_date.end_of_month

      total_created = 0
      total_errors = 0

      User.joins(:customers).distinct.find_each do |user|
        user.customers.active.each do |customer|
          result = generate_appointments_for_customer_and_month(customer, month_start, month_end)
          total_created += result[:created]
          total_errors += result[:errors]
        end
      end

      Rails.logger.info "Manual generation completed: #{total_created} created, #{total_errors} errors"
      { created: total_created, errors: total_errors }
    end

    def setup_recurring_schedule
      # This should be called once to set up the recurring job
      # You can call this from an initializer or manually

      # Remove any existing scheduled jobs for this
      cancel_scheduled_jobs

      # Schedule the next one
      schedule_monthly_generation

      Rails.logger.info "Monthly appointment generation schedule set up successfully"
    end

    def next_scheduled_run
      return nil unless defined?(Sidekiq)

      begin
        require "sidekiq/api"
        scheduled_jobs = Sidekiq::ScheduledSet.new
        next_job = scheduled_jobs.select { |job| job.klass == "MonthlyAppointmentGenerationJob" }.first

        if next_job
          Time.at(next_job.at)
        else
          nil
        end
      rescue => e
        Rails.logger.error "Error checking scheduled jobs: #{e.message}"
        nil
      end
    end

    def cancel_scheduled_jobs
      return 0 unless defined?(Sidekiq)

      begin
        require "sidekiq/api"
        scheduled_jobs = Sidekiq::ScheduledSet.new
        cancelled_count = 0

        scheduled_jobs.select { |job| job.klass == "MonthlyAppointmentGenerationJob" }.each do |job|
          job.delete
          cancelled_count += 1
        end

        Rails.logger.info "Cancelled #{cancelled_count} scheduled monthly appointment generation jobs"
        cancelled_count
      rescue => e
        Rails.logger.error "Error cancelling scheduled jobs: #{e.message}"
        0
      end
    end

    # Preview what would be generated for a specific month
    def preview_generation_for_month(target_month, target_year)
      Rails.logger.info "Previewing appointment generation for: #{target_month}/#{target_year}"

      target_date = Date.new(target_year, target_month, 1)
      month_start = target_date.beginning_of_month
      month_end = target_date.end_of_month

      preview_data = []
      total_would_create = 0

      User.joins(:customers).distinct.find_each do |user|
        user.customers.active.each do |customer|
          customer_preview = preview_customer_appointments(customer, month_start, month_end)
          if customer_preview[:appointments].any?
            preview_data << {
              customer: customer,
              appointments: customer_preview[:appointments],
              patterns: customer_preview[:patterns]
            }
            total_would_create += customer_preview[:appointments].count
          end
        end
      end

      {
        month_name: target_date.strftime("%B de %Y"),
        month_start: month_start,
        month_end: month_end,
        total_would_create: total_would_create,
        customers_data: preview_data
      }
    end

    private

    def preview_customer_appointments(customer, month_start, month_end)
      # Analyze patterns without creating appointments
      pattern_start = 2.months.ago.beginning_of_month
      pattern_end = Date.current.end_of_month

      recent_appointments = customer.appointments
                                    .where(scheduled_at: pattern_start..pattern_end)
                                    .where(status: [ "scheduled", "completed" ])
                                    .order(:scheduled_at)

      return { appointments: [], patterns: [] } if recent_appointments.empty?

      # Detect patterns
      grouped = recent_appointments.group_by do |apt|
        {
          wday: apt.scheduled_at.wday,
          hour: apt.scheduled_at.hour,
          minute: apt.scheduled_at.minute,
          duration: apt.duration
        }
      end

      patterns = []
      preview_appointments = []

      grouped.each do |pattern_key, pattern_appointments|
        next if pattern_appointments.count < 3  # Only patterns with 3+ occurrences

        patterns << {
          day_name: Date::DAYNAMES[pattern_key[:wday]],
          time: "#{pattern_key[:hour].to_s.rjust(2, '0')}:#{pattern_key[:minute].to_s.rjust(2, '0')}",
          duration: pattern_key[:duration],
          frequency: pattern_appointments.count
        }

        # Preview what would be created for this pattern
        current_date = month_start
        while current_date <= month_end
          if current_date.wday == pattern_key[:wday]
            appointment_time = Time.zone.local(
              current_date.year,
              current_date.month,
              current_date.day,
              pattern_key[:hour],
              pattern_key[:minute]
            )

            # Check if appointment would be created (no existing conflict)
            unless customer.appointments.where(scheduled_at: appointment_time).exists?
              preview_appointments << {
                scheduled_at: appointment_time,
                duration: pattern_key[:duration],
                pattern: patterns.last
              }
            end
          end
          current_date += 1.day
        end
      end

      {
        appointments: preview_appointments,
        patterns: patterns
      }
    end

    def generate_appointments_for_customer_and_month(customer, month_start, month_end)
      # This is a simplified version for manual generation
      pattern_start = 2.months.ago.beginning_of_month
      pattern_end = Date.current.end_of_month

      recent_appointments = customer.appointments
                                    .where(scheduled_at: pattern_start..pattern_end)
                                    .where(status: [ "scheduled", "completed" ])
                                    .order(:scheduled_at)

      return { created: 0, errors: 0 } if recent_appointments.empty?

      # Detect the most common pattern
      grouped = recent_appointments.group_by do |apt|
        {
          wday: apt.scheduled_at.wday,
          hour: apt.scheduled_at.hour,
          minute: apt.scheduled_at.minute,
          duration: apt.duration
        }
      end

      # Get the most frequent pattern
      most_common_pattern = grouped.max_by { |_, appointments| appointments.count }
      return { created: 0, errors: 0 } unless most_common_pattern

      pattern_key, pattern_appointments = most_common_pattern
      return { created: 0, errors: 0 } if pattern_appointments.count < 2

      # Create appointments based on this pattern
      created_count = 0
      current_date = month_start

      while current_date <= month_end
        if current_date.wday == pattern_key[:wday]
          appointment_time = Time.zone.local(
            current_date.year,
            current_date.month,
            current_date.day,
            pattern_key[:hour],
            pattern_key[:minute]
          )

          unless customer.appointments.where(scheduled_at: appointment_time).exists?
            appointment = Appointment.create(
              customer: customer,
              scheduled_at: appointment_time,
              duration: pattern_key[:duration],
              status: "scheduled",
              notes: "Auto-gerado manualmente em #{Date.current.strftime('%d/%m/%Y')}"
            )

            created_count += 1 if appointment.persisted?
          end
        end

        current_date += 1.day
      end

      { created: created_count, errors: 0 }
    end
  end
end
