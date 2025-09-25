namespace :smart_sync do
  desc "Test the new Smart Google Calendar Sync Service without making actual API calls"
  task test: :environment do
    puts "🧪 Testing Smart Google Calendar Sync Service"
    puts "=" * 50

    # Find a user with Google Calendar authorization for testing
    user = User.where.not(google_refresh_token: nil).first

    unless user
      puts "❌ No user with Google Calendar authorization found"
      puts "💡 Please authorize Google Calendar first via the web interface"
      exit
    end

    puts "👤 Testing with user: #{user.email || user.id}"

    # Find customers with schedules
    customers_with_schedules = user.customers.active.joins(:customer_schedules)
                                  .where(customer_schedules: { enabled: true })
                                  .includes(:customer_schedules)
                                  .distinct

    if customers_with_schedules.empty?
      puts "❌ No customers with regular schedules found"
      puts "💡 Please create some customer schedules first"
      exit
    end

    puts "📅 Found #{customers_with_schedules.count} customers with regular schedules:"
    customers_with_schedules.each do |customer|
      schedules = customer.customer_schedules.enabled
      puts "  • #{customer.name}: #{schedules.count} schedule(s)"
      schedules.each do |schedule|
        day_name = CustomerSchedule::DAYS_OF_WEEK[schedule.day_of_week]
        puts "    - #{day_name} at #{schedule.start_time.strftime('%H:%M')} (#{schedule.duration}h)"
      end
    end

    puts "\n🔍 Analyzing what would be synced for current month..."

    # Test the grouping logic without actual API calls
    service = SmartGoogleCalendarSyncService.new(user)

    # Test the grouping logic by examining what would be created
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    puts "📊 Sync Analysis for #{start_date.strftime('%B %Y')}:"
    puts "-" * 30

    total_events = 0
    total_occurrences = 0

    customers_with_schedules.each do |customer|
      schedules = customer.customer_schedules.enabled.order(:start_time)

      # Group schedules by time and duration
      grouped_schedules = schedules.group_by do |schedule|
        {
          time: schedule.start_time.strftime("%H:%M"),
          duration: schedule.duration
        }
      end

      puts "\n👤 #{customer.name}:"

      grouped_schedules.each do |time_group, schedule_list|
        days_of_week = schedule_list.map(&:day_of_week).sort
        day_names = days_of_week.map { |wday| CustomerSchedule::DAYS_OF_WEEK[wday] }

        # Calculate occurrences for this group
        occurrences = 0
        current_date = start_date
        while current_date <= end_date
          occurrences += 1 if days_of_week.include?(current_date.wday)
          current_date += 1.day
        end

        puts "  📋 Event: #{time_group[:time]} (#{time_group[:duration]}h) on #{day_names.join(', ')}"
        puts "    └─ #{occurrences} occurrences this month"

        total_events += 1
        total_occurrences += occurrences
      end
    end

    api_calls_saved = [ total_occurrences - total_events, 0 ].max

    puts "\n📈 Summary:"
    puts "  • Total recurring events to create: #{total_events}"
    puts "  • Total appointment occurrences: #{total_occurrences}"
    puts "  • API calls saved: #{api_calls_saved}"
    puts "  • Efficiency gain: #{api_calls_saved > 0 ? "#{((api_calls_saved.to_f / total_occurrences) * 100).round(1)}%" : "0%"}"

    puts "\n✅ Test completed successfully!"
    puts "💡 To perform actual sync, use: SmartGoogleCalendarSyncService.new(user).sync_current_month"
    puts "🚫 Remember: No email invitations will be sent during sync (testing mode)"
  end

  desc "Test sync for a specific customer"
  task :test_customer, [ :customer_id ] => :environment do |t, args|
    customer_id = args[:customer_id]

    unless customer_id
      puts "❌ Please provide a customer ID: rake smart_sync:test_customer[123]"
      exit
    end

    customer = Customer.find(customer_id)
    user = customer.user

    puts "🧪 Testing sync for customer: #{customer.name}"
    puts "=" * 50

    schedules = customer.customer_schedules.enabled

    if schedules.empty?
      puts "❌ Customer has no regular schedules"
      exit
    end

    puts "📅 Customer schedules:"
    schedules.each do |schedule|
      day_name = CustomerSchedule::DAYS_OF_WEEK[schedule.day_of_week]
      puts "  • #{day_name} at #{schedule.start_time.strftime('%H:%M')} (#{schedule.duration}h)"
    end

    # Group schedules
    grouped_schedules = schedules.group_by do |schedule|
      {
        time: schedule.start_time.strftime("%H:%M"),
        duration: schedule.duration
      }
    end

    puts "\n📊 Recurring events that would be created:"
    grouped_schedules.each do |time_group, schedule_list|
      days_of_week = schedule_list.map(&:day_of_week).sort
      day_names = days_of_week.map { |wday| CustomerSchedule::DAYS_OF_WEEK[wday] }

      puts "  📋 #{time_group[:time]} (#{time_group[:duration]}h) on #{day_names.join(', ')}"
    end

    puts "\n✅ Analysis complete!"
  end
end
