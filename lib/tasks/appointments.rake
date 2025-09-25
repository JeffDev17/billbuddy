namespace :appointments do
  desc "Run smart appointment generation for all users"
  task smart_generate: :environment do
    puts "Running smart appointment generation for all users..."

    result = AppointmentGenerationScheduler.run_smart_generation_now

    puts "Smart generation completed:"
    puts "- Current month filled: #{result[:current_month_filled]}"
    puts "- Next month created: #{result[:next_month_created]}"
    puts "- Customers processed: #{result[:customers_processed]}"

    if result[:errors].any?
      puts "Errors occurred:"
      result[:errors].each { |error| puts "  - #{error}" }
    end
  end

  desc "Run smart appointment generation for specific user by email"
  task :smart_generate_for_user, [ :email ] => :environment do |t, args|
    email = args[:email]

    unless email
      puts "Usage: rake appointments:smart_generate_for_user[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)
    unless user
      puts "User with email '#{email}' not found"
      exit 1
    end

    puts "Running smart appointment generation for #{user.email}..."

    result = AppointmentGenerationScheduler.run_smart_generation_now(user.id)

    puts "Smart generation completed for #{user.email}:"
    puts "- Current month filled: #{result[:current_month_filled]}"
    puts "- Next month created: #{result[:next_month_created]}"
    puts "- Customers processed: #{result[:customers_processed]}"

    if result[:errors].any?
      puts "Errors occurred:"
      result[:errors].each { |error| puts "  - #{error}" }
    end
  end

  desc "Generate appointments for next month only"
  task generate_next_month: :environment do
    puts "Generating appointments for next month only..."

    total_created = 0
    total_errors = 0

    User.joins(:customers).distinct.find_each do |user|
      result = AppointmentGenerationScheduler.generate_next_month_for_user(user)
      total_created += result[:created]
      total_errors += result[:errors].count

      puts "User #{user.email}: #{result[:created]} appointments created"
    end

    puts "Next month generation completed: #{total_created} created, #{total_errors} errors"
  end

  desc "Generate appointments for a specific customer by name and user email"
  task :generate_for_customer, [ :user_email, :customer_name ] => :environment do |t, args|
    user_email = args[:user_email]
    customer_name = args[:customer_name]

    unless user_email && customer_name
      puts "Usage: rake appointments:generate_for_customer[user@example.com,'Customer Name']"
      exit 1
    end

    user = User.find_by(email: user_email)
    unless user
      puts "User with email '#{user_email}' not found"
      exit 1
    end

    customer = user.customers.find_by("name ILIKE ?", "%#{customer_name}%")
    unless customer
      puts "Customer with name containing '#{customer_name}' not found for user #{user_email}"
      exit 1
    end

    puts "Generating appointments for customer: #{customer.name} (#{user.email})"

    result = AppointmentGenerationScheduler.generate_for_customer(customer)

    puts "Generation completed for #{customer.name}:"
    puts "- Current month filled: #{result[:current_month_filled]}"
    puts "- Next month created: #{result[:next_month_created]}"

    if result[:errors].any?
      puts "Errors occurred:"
      result[:errors].each { |error| puts "  - #{error}" }
    end
  end

  desc "Setup smart appointment generation schedule"
  task setup_smart_schedule: :environment do
    puts "Setting up smart appointment generation schedule..."

    AppointmentGenerationScheduler.setup_smart_generation_schedule

    puts "Smart schedule setup completed!"
    puts "- Daily current month checks scheduled"
    puts "- Weekly next month generation scheduled"
    puts "- Monthly long-term generation scheduled"
  end

  desc "Show appointment generation statistics for current and next month"
  task stats: :environment do
    puts "Appointment Generation Statistics"
    puts "=" * 40

    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    next_month_start = Date.current.next_month.beginning_of_month
    next_month_end = Date.current.next_month.end_of_month

    User.joins(:customers).distinct.find_each do |user|
      puts "\nUser: #{user.email}"

      current_month_appointments = Appointment.joins(:customer)
                                             .where(customers: { user_id: user.id })
                                             .where(scheduled_at: current_month_start..current_month_end)
                                             .count

      next_month_appointments = Appointment.joins(:customer)
                                          .where(customers: { user_id: user.id })
                                          .where(scheduled_at: next_month_start..next_month_end)
                                          .count

      active_customers = user.customers.active.count

      puts "  Active customers: #{active_customers}"
      puts "  Current month appointments: #{current_month_appointments}"
      puts "  Next month appointments: #{next_month_appointments}"
    end
  end
end
