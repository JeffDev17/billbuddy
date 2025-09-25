# WhatsApp Service Auto-Start Configuration
Rails.application.configure do
  # Only start WhatsApp service in development and production
  if Rails.env.development? || Rails.env.production?

    # Ensure Node.js dependencies are installed
    whatsapp_dir = Rails.root.join("whatsapp-api")

    unless File.exist?(whatsapp_dir.join("node_modules"))
      Rails.logger.info "Installing WhatsApp Node.js dependencies..."
      system("cd #{whatsapp_dir} && npm install")
    end

    # Auto-start WhatsApp service when Rails starts
    config.after_initialize do
      Rails.logger.info "WhatsApp service will start automatically in 10 seconds..."
      Thread.new do
        # Wait longer for Rails to fully start and stabilize
        sleep(10)
        begin
          Rails.logger.info "Starting WhatsApp service..."
          WhatsappProcessManager.start!
        rescue => e
          Rails.logger.error "Failed to auto-start WhatsApp service: #{e.message}"
        end
      end
    end

    # Gracefully stop the WhatsApp service when Rails shuts down
    at_exit do
      WhatsappProcessManager.stop!
    end
  end
end
