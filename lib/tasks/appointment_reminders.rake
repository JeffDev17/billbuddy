namespace :appointment_reminders do
  desc "Preview upcoming appointment reminders (dry-run)"
  task preview: :environment do
    result = AppointmentReminderService.preview_upcoming_reminders

    puts "\n=== APPOINTMENT REMINDERS PREVIEW ==="
    puts "Total eligible appointments: #{result[:count]}"
    puts "\n"

    if result[:count].zero?
      puts "No appointments found in the 30-minute window."
    else
      result[:appointments].each_with_index do |apt, index|
        puts "#{index + 1}. Appointment ##{apt[:id]}"
        puts "   Customer: #{apt[:customer_name]}"
        puts "   Phone: #{apt[:customer_phone]}"
        puts "   Scheduled: #{apt[:scheduled_at]}"
        puts "   Time until: #{apt[:time_until]}"
        puts "\n   Message preview:"
        apt[:message].lines.each { |line| puts "   #{line}" }
        puts "\n"
      end
    end
  end

  desc "Send appointment reminders NOW (use with caution)"
  task send: :environment do
    puts "\n⚠️  WARNING: This will send real WhatsApp messages!"
    puts "Press Ctrl+C to cancel, or press Enter to continue..."
    STDIN.gets

    result = AppointmentReminderService.preview_upcoming_reminders
    puts "\nSending reminders to #{result[:count]} appointments..."

    AppointmentReminderService.send_upcoming_reminders

    puts "✓ Reminders sent successfully!"
  end

  desc "Send reminder for specific appointment ID"
  task :send_one, [ :appointment_id ] => :environment do |_t, args|
    appointment_id = args[:appointment_id]

    unless appointment_id
      puts "Usage: rake appointment_reminders:send_one[APPOINTMENT_ID]"
      exit 1
    end

    appointment = Appointment.find(appointment_id)
    service = AppointmentReminderService.new(appointment.customer.user)

    puts "\n=== SENDING REMINDER ==="
    puts "Appointment ##{appointment.id}"
    puts "Customer: #{appointment.customer.name}"
    puts "Phone: #{appointment.customer.phone}"
    puts "Scheduled at: #{appointment.scheduled_at}"
    puts "\n"

    service.send_reminder_for(appointment, force: true)

    puts "✓ Reminder sent successfully!"
  rescue ActiveRecord::RecordNotFound
    puts "❌ Appointment ##{appointment_id} not found"
  rescue StandardError => e
    puts "❌ Error: #{e.message}"
  end

  desc "Check system status for reminders"
  task status: :environment do
    puts "\n=== APPOINTMENT REMINDER SYSTEM STATUS ==="

    scheduled_count = Appointment.where(status: "scheduled").count
    future_count = Appointment.where(status: "scheduled").where("scheduled_at > ?", Time.current).count
    reminded_count = Appointment.where.not(reminder_sent_at: nil).count

    puts "Total scheduled appointments: #{scheduled_count}"
    puts "Future scheduled appointments: #{future_count}"
    puts "Appointments already reminded: #{reminded_count}"
    puts "\n"

    thirty_min_window = 28.minutes.from_now..32.minutes.from_now
    upcoming = Appointment.needs_reminder_soon(thirty_min_window)

    puts "Appointments in 30-min window: #{upcoming.count}"

    if upcoming.any?
      puts "\nUpcoming reminders:"
      upcoming.each do |apt|
        minutes = ((apt.scheduled_at - Time.current) / 60).round
        puts "  - #{apt.customer.name} at #{apt.scheduled_at.strftime('%H:%M')} (in #{minutes} min)"
      end
    end

    puts "\n"
  end
end
