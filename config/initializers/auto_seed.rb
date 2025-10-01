# Auto-seed demo data after Rails starts
Rails.logger.info "🔍 Auto-seed initializer loading... ENV['AUTO_SEED']=#{ENV['AUTO_SEED']}, Rails.env=#{Rails.env}"

if Rails.env.production? && ENV["AUTO_SEED"] == "true"
  Rails.logger.info "🌱 Auto-seed conditions met, setting up initializer..."

  Rails.application.config.after_initialize do
    Rails.logger.info "🎭 Auto-seed initializer executing..."

    begin
      # Run directly instead of thread to see errors immediately
      Rails.logger.info "🌱 Loading seeds directly..."
      load Rails.root.join("db", "seeds.rb")
      Rails.logger.info "✅ Auto-seed completed successfully!"
    rescue => e
      Rails.logger.error "❌ Auto-seed failed: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(10).join("\n")}"
    end
  end
else
  Rails.logger.info "❌ Auto-seed conditions not met"
end
