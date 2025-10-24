# WhatsApp Service Auto-Start Configuration
# TODO: WhatsApp temporariamente desativado

Rails.application.configure do
  # WhatsApp desativado
  # if Rails.env.development? || Rails.env.production?
  #   whatsapp_dir = Rails.root.join("whatsapp-api")
  #   unless File.exist?(whatsapp_dir.join("node_modules"))
  #     Rails.logger.info "Installing WhatsApp Node.js dependencies..."
  #     system("cd #{whatsapp_dir} && npm install")
  #   end
  #   config.after_initialize do
  #     Rails.logger.info "WhatsApp service will start automatically in 10 seconds..."
  #     Thread.new do
  #       sleep(10)
  #       begin
  #         Rails.logger.info "Starting WhatsApp service..."
  #         WhatsappProcessManager.start!
  #       rescue => e
  #         Rails.logger.error "Failed to auto-start WhatsApp service: #{e.message}"
  #       end
  #     end
  #   end
  #   at_exit do
  #     Rails.logger.info "Rails shutting down, stopping WhatsApp service..."
  #     WhatsappProcessManager.stop!
  #   end
  #   Signal.trap("INT") do
  #     Rails.logger.info "Received SIGINT, stopping WhatsApp service..."
  #     WhatsappProcessManager.stop!
  #     exit
  #   end
  #   Signal.trap("TERM") do
  #     Rails.logger.info "Received SIGTERM, stopping WhatsApp service..."
  #     WhatsappProcessManager.stop!
  #     exit
  #   end
  # end
end
