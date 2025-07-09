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

    # Disable auto-start to prevent conflicts
    # Use bin/rails whatsapp:start to manually start the service when needed

    # Gracefully stop the WhatsApp service when Rails shuts down
    at_exit do
      WhatsappProcessManager.stop!
    end
  end
end
