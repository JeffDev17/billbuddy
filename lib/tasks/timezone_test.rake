namespace :timezone do
  desc "Test timezone configuration"
  task test: :environment do
    puts "=== TIMEZONE TEST ==="
    puts "Rails.application.config.time_zone: #{Rails.application.config.time_zone}"
    puts "Time.zone: #{Time.zone}"
    puts "Time.zone.now: #{Time.zone.now}"
    puts "Time.zone.now.strftime: #{Time.zone.now.strftime('%d/%m/%Y %H:%M:%S %Z')}"
    puts "Date.current: #{Date.current}"
    puts "Time.current: #{Time.current.strftime('%d/%m/%Y %H:%M:%S %Z')}"
    
    # Test database time
    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.active?
      puts "\n=== DATABASE TIME ==="
      result = ActiveRecord::Base.connection.execute("SELECT NOW() as current_time")
      puts "Database NOW(): #{result.first['current_time']}"
      
      # Test appointment creation
      if Appointment.any?
        appointment = Appointment.first
        puts "\n=== APPOINTMENT TEST ==="
        puts "First appointment scheduled_at: #{appointment.scheduled_at}"
        puts "Formatted: #{appointment.scheduled_at.in_time_zone('America/Sao_Paulo').strftime('%d/%m/%Y %H:%M:%S %Z')}"
      end
    end
    
    puts "\n=== TEST COMPLETE ==="
  end
end 