# Auto-seed demo data after Rails starts
if Rails.env.production? && ENV["AUTO_SEED"] == "true"
  Rails.application.config.after_initialize do
    Rails.logger.info "🌱 Auto-seeding demo data..."
    begin
      load Rails.root.join("db", "seeds.rb")
    rescue => e
      Rails.logger.error "❌ Auto-seed failed: #{e.message}"
    end
  end
end
