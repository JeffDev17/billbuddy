# Auto-seed demo data after Rails starts
if Rails.env.production? && ENV["AUTO_SEED"] == "true"
  Rails.application.config.after_initialize do
    Rails.logger.info "🌱 Auto-seeding demo data..."
    begin
      # Use a thread to avoid blocking app startup
      Thread.new do
        sleep(2) # Wait for app to fully initialize
        Rails.logger.info "🎭 Running seeds..."
        load Rails.root.join("db", "seeds.rb")
        Rails.logger.info "✅ Auto-seed completed successfully!"
      end
    rescue => e
      Rails.logger.error "❌ Auto-seed failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end
end
