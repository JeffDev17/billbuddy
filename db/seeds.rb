# Demo data for BillBuddy
if Rails.env.production? && ENV['AUTO_SEED'] == 'true'
  puts "🎭 Creating demo data for BillBuddy..."

  # Create demo user
  demo_user = User.find_or_create_by!(email: "demo@billbuddy.com") do |user|
    user.password = "demo123456"
    user.password_confirmation = "demo123456"
  end

  puts "✅ Demo user created: demo@billbuddy.com / demo123456"

  # Create demo customers
  customers_data = [
    { name: "Alice Johnson", email: "alice@email.com", status: "active", plan_type: "subscription", monthly_amount: 400, monthly_hours: 8 },
    { name: "Bob Wilson", email: "bob@email.com", status: "active", plan_type: "credit", custom_hourly_rate: 75 },
    { name: "Carol Davis", email: "carol@email.com", status: "active", plan_type: "subscription", monthly_amount: 600, monthly_hours: 12 },
    { name: "David Miller", email: "david@email.com", status: "active", plan_type: "credit", custom_hourly_rate: 80 },
    { name: "Emma Brown", email: "emma@email.com", status: "active", plan_type: "subscription", monthly_amount: 300, monthly_hours: 6 }
  ]

  customers_data.each do |customer_data|
    customer = demo_user.customers.find_or_create_by!(name: customer_data[:name]) do |c|
      c.assign_attributes(customer_data)
    end

    # Create sample appointments for each customer
    3.times do |i|
      date = (Date.current - i.weeks)
      Appointment.find_or_create_by!(
        customer: customer,
        scheduled_at: date + 10.hours,
        duration: 1.5,
        status: "completed"
      )
    end

    # Create some payments
    2.times do |i|
      Payment.find_or_create_by!(
        customer: customer,
        amount: customer_data[:monthly_amount] || 150,
        payment_date: Date.current - i.months,
        status: "paid",
        payment_type: customer_data[:plan_type],
        payment_method: "pix"
      )
    end
  end

  puts "✅ Demo customers and data created!"
  puts "🎉 BillBuddy demo is ready!"
end
