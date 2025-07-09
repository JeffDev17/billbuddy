# Timezone configuration for Brazil/São Paulo
Rails.application.configure do
  # Set application timezone
  config.time_zone = "America/Sao_Paulo"
  
  # Ensure ActiveRecord uses local time
  config.active_record.default_timezone = :local
end

# Set timezone for the current thread (useful for console and tests)
Time.zone = "America/Sao_Paulo" 