namespace :whatsapp do
  desc "Start WhatsApp service"
  task start: :environment do
    puts "🚀 Starting WhatsApp service..."

    if WhatsappProcessManager.start!
      puts "✅ WhatsApp service started successfully on port #{WhatsappProcessManager.port}"
      puts "📊 Check status at: http://localhost:#{WhatsappProcessManager.port}/status"
    else
      puts "❌ Failed to start WhatsApp service. Check logs at log/whatsapp.log"
      exit 1
    end
  end

  desc "Stop WhatsApp service"
  task stop: :environment do
    puts "🛑 Stopping WhatsApp service..."

    if WhatsappProcessManager.stop!
      puts "✅ WhatsApp service stopped successfully"
    else
      puts "❌ Failed to stop WhatsApp service"
      exit 1
    end
  end

  desc "Restart WhatsApp service"
  task restart: :environment do
    puts "🔄 Restarting WhatsApp service..."

    if WhatsappProcessManager.restart!
      puts "✅ WhatsApp service restarted successfully on port #{WhatsappProcessManager.port}"
      puts "📊 Check status at: http://localhost:#{WhatsappProcessManager.port}/status"
    else
      puts "❌ Failed to restart WhatsApp service. Check logs at log/whatsapp.log"
      exit 1
    end
  end

  desc "Check WhatsApp service status"
  task status: :environment do
    puts "📊 Checking WhatsApp service status..."

    if WhatsappProcessManager.running?
      status = WhatsappProcessManager.status
      puts "✅ WhatsApp service is running"
      puts "   Port: #{status[:port]}"
      puts "   Status: #{status[:status]}"
      puts "   URL: #{WhatsappProcessManager.api_url}"
    else
      puts "❌ WhatsApp service is not running"
    end
  end

  desc "Clean up WhatsApp processes and start fresh"
  task clean_start: :environment do
    puts "🧹 Performing clean start of WhatsApp service..."

    # Force stop and cleanup
    WhatsappProcessManager.stop!

    # Additional cleanup
    puts "   Cleaning up any remaining processes..."
    system("pkill -f 'node.*app.js' 2>/dev/null || true")
    system("pkill -f 'chrome.*whatsapp' 2>/dev/null || true")

    sleep(3)

    # Start fresh
    if WhatsappProcessManager.start!
      puts "✅ WhatsApp service started fresh on port #{WhatsappProcessManager.port}"
    else
      puts "❌ Failed to start WhatsApp service after cleanup"
      exit 1
    end
  end

  desc "Show WhatsApp service logs"
  task logs: :environment do
    log_file = Rails.root.join("log", "whatsapp.log")

    if File.exist?(log_file)
      puts "📋 WhatsApp service logs (last 50 lines):"
      puts "=" * 50
      system("tail -50 #{log_file}")
    else
      puts "📋 No WhatsApp logs found at #{log_file}"
    end
  end

  desc "Follow WhatsApp service logs in real-time"
  task follow_logs: :environment do
    log_file = Rails.root.join("log", "whatsapp.log")

    if File.exist?(log_file)
      puts "📋 Following WhatsApp service logs (Press Ctrl+C to stop):"
      puts "=" * 50
      exec("tail -f #{log_file}")
    else
      puts "📋 No WhatsApp logs found at #{log_file}"
      puts "    Start the service first with: bin/rails whatsapp:start"
    end
  end
end
