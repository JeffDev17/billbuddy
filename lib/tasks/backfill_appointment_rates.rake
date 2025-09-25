namespace :appointments do
  desc "Backfill hourly rates for existing appointments"
  task backfill_rates: :environment do
    puts "Starting to backfill appointment rates..."

    count = 0
    total = Appointment.count

    Appointment.includes(:customer).find_each(batch_size: 100) do |appointment|
      next if appointment.hourly_rate.present? # Skip if already has rate

      customer = appointment.customer

      # Calculate rate using current customer logic
      rate = if customer.custom_hourly_rate.present?
        customer.custom_hourly_rate
      elsif customer.monthly_amount.present? && customer.monthly_hours.present? && customer.monthly_hours > 0
        (customer.monthly_amount / customer.monthly_hours)
      else
        50.0 # Default rate
      end

      # Determine source
      source = if customer.custom_hourly_rate.present?
        "custom"
      elsif customer.monthly_amount.present? && customer.monthly_hours.present?
        "monthly_package"
      else
        "default"
      end

      appointment.update_columns(
        hourly_rate: rate,
        rate_source: source
      )

      count += 1
      puts "Processed #{count}/#{total} appointments..." if count % 100 == 0
    end

    puts "✅ Backfilled rates for #{count} appointments!"
  end
end
