# Auto-seed demo data after Rails starts
if Rails.env.production? && ENV["AUTO_SEED"] == "true"
  Rails.application.config.after_initialize do
    Rails.logger.info "🌱 Auto-seeding demo data..."
    begin
      load Rails.root.join("db", "seeds.rb")
      Rails.logger.info "✅ Auto-seed completed successfully!"
    rescue => e
      Rails.logger.error "❌ Auto-seed failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end
end
