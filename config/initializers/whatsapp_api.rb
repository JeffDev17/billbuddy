# Configure WhatsApp API URL based on environment
Rails.application.config.after_initialize do
  if Rails.env.development?
    ENV["WHATSAPP_API_URL"] = "http://localhost.billbuddy.com.br:3001"
  end
end
