# Demo data for BillBuddy
if Rails.env.production? && ENV['AUTO_SEED'] == 'true'
  puts "🎭 Creating demo data for BillBuddy..."

  # Create demo user
  demo_user = User.find_or_create_by!(email: "demo@billbuddy.com") do |user|
    user.password = "demo123456"
    user.password_confirmation = "demo123456"
    puts "🔐 Setting password for demo user..."
  end

  # Verify user creation and password
  if demo_user.persisted?
    puts "✅ Demo user created: #{demo_user.email}"
    puts "🔑 Password hash present: #{demo_user.encrypted_password.present?}"

    # Test password validation
    if demo_user.valid_password?("demo123456")
      puts "✅ Password validation working correctly"
    else
      puts "❌ Password validation failed - updating..."
      demo_user.update!(password: "demo123456", password_confirmation: "demo123456")
    end
  else
    puts "❌ Failed to create demo user: #{demo_user.errors.full_messages}"
    raise "Demo user creation failed"
  end

  # Create diverse demo customers
  customers_data = [
    { name: "Ana Silva", email: "ana@email.com", status: "active", plan_type: "subscription", monthly_amount: 480, monthly_hours: 8, activated_at: 8.months.ago },
    { name: "Bruno Costa", email: "bruno@email.com", status: "active", plan_type: "credit", custom_hourly_rate: 85, activated_at: 10.months.ago },
    { name: "Carla Santos", email: "carla@email.com", status: "active", plan_type: "subscription", monthly_amount: 720, monthly_hours: 12, activated_at: 6.months.ago },
    { name: "Diego Ferreira", email: "diego@email.com", status: "active", plan_type: "credit", custom_hourly_rate: 90, activated_at: 4.months.ago },
    { name: "Elena Rodrigues", email: "elena@email.com", status: "active", plan_type: "subscription", monthly_amount: 360, monthly_hours: 6, activated_at: 7.months.ago },
    { name: "Felipe Oliveira", email: "felipe@email.com", status: "inactive", plan_type: "credit", custom_hourly_rate: 75, activated_at: 11.months.ago, cancelled_at: 2.months.ago },
    { name: "Gabriela Lima", email: "gabriela@email.com", status: "on_hold", plan_type: "subscription", monthly_amount: 400, monthly_hours: 8, activated_at: 5.months.ago },
    { name: "Henrique Alves", email: "henrique@email.com", status: "active", plan_type: "credit", custom_hourly_rate: 95, activated_at: 3.months.ago },
    { name: "Isabela Martins", email: "isabela@email.com", status: "active", plan_type: "subscription", monthly_amount: 600, monthly_hours: 10, activated_at: 9.months.ago },
    { name: "João Pereira", email: "joao@email.com", status: "active", plan_type: "credit", custom_hourly_rate: 80, activated_at: 1.month.ago }
  ]

  puts "📅 Creating customers and appointments throughout the year..."

  customers_data.each_with_index do |customer_data, index|
    customer = demo_user.customers.find_or_create_by!(name: customer_data[:name]) do |c|
      c.assign_attributes(customer_data.except(:activated_at, :cancelled_at))
      c.activated_at = customer_data[:activated_at]
      c.cancelled_at = customer_data[:cancelled_at] if customer_data[:cancelled_at]
    end

    # Generate appointments throughout the year
    start_date = customer_data[:activated_at].to_date
    end_date = customer_data[:cancelled_at]&.to_date || Date.current.end_of_year

    current_date = start_date
    appointment_count = 0

    while current_date <= end_date && appointment_count < 50
      # Skip weekends for most appointments
      if current_date.wday.between?(1, 6) # Monday to Saturday
        # 70% chance of having an appointment on any given eligible day
        if rand < 0.7
          # Vary appointment times
          hour = [ 8, 9, 10, 11, 14, 15, 16, 17, 18, 19 ].sample
          scheduled_at = current_date + hour.hours

          # Determine status based on date
          status = if current_date < Date.current - 1.week
            # Past appointments: 80% completed, 15% cancelled, 5% no_show
            rand_status = rand
            if rand_status < 0.80
              "completed"
            elsif rand_status < 0.95
              "cancelled"
            else
              "no_show"
            end
          elsif current_date < Date.current
            # Recent past: 90% completed, 10% cancelled
            rand < 0.9 ? "completed" : "cancelled"
          else
            # Future appointments: all scheduled
            "scheduled"
          end

          # Vary duration: 1h, 1.5h, or 2h
          duration = [ 1.0, 1.5, 2.0 ].sample

          # Add some notes for variety
          notes = case status
          when "cancelled"
            [ "Reagendado pelo cliente", "Emergência familiar", "Conflito de horário", nil ].sample
          when "no_show"
            [ "Cliente não compareceu", "Sem aviso prévio" ].sample
          when "completed"
            [ "Sessão excelente!", "Progresso notável", "Revisão de conteúdo", nil ].sample
          else
            nil
          end

          # Set cancellation type for cancelled appointments
          cancellation_type = if status == "cancelled"
            # 40% pending_reschedule, 20% with_revenue, 40% standard
            rand_cancel = rand
            if rand_cancel < 0.4
              "pending_reschedule"
            elsif rand_cancel < 0.6
              "with_revenue"
            else
              "standard"
            end
          else
            nil
          end

          Appointment.find_or_create_by!(
            customer: customer,
            scheduled_at: scheduled_at
          ) do |apt|
            apt.duration = duration
            apt.status = status
            apt.notes = notes
            apt.cancellation_type = cancellation_type
            apt.hourly_rate = customer_data[:custom_hourly_rate] if customer_data[:plan_type] == "credit"
          end

          appointment_count += 1
        end
      end

      current_date += 1.day
    end

    # Create realistic payments
    if customer_data[:plan_type] == "subscription"
      # Monthly payments from activation date
      payment_date = start_date.beginning_of_month
      while payment_date <= Date.current && payment_date <= (customer_data[:cancelled_at] || Date.current)
        # 90% of payments are on time, 10% are late
        actual_payment_date = rand < 0.9 ? payment_date : payment_date + rand(1..15).days

        Payment.find_or_create_by!(
          customer: customer,
          payment_date: actual_payment_date
        ) do |payment|
          payment.amount = customer_data[:monthly_amount]
          payment.status = actual_payment_date <= Date.current ? "paid" : "pending"
          payment.payment_type = "subscription"
          payment.payment_method = [ "pix", "bank_transfer", "credit_card" ].sample
          payment.received_at = payment.status == "paid" ? actual_payment_date + rand(0..2).days : nil
        end

        payment_date += 1.month
      end
    else
      # Credit-based payments - more sporadic
      completed_appointments = customer.appointments.where(status: "completed")
      completed_appointments.group_by { |apt| apt.scheduled_at.beginning_of_month }.each do |month, appointments|
        total_hours = appointments.sum(&:duration)
        total_amount = total_hours * customer_data[:custom_hourly_rate]

        if total_amount > 0
          payment_date = month + rand(5..25).days

          Payment.find_or_create_by!(
            customer: customer,
            payment_date: payment_date
          ) do |payment|
            payment.amount = total_amount
            payment.status = payment_date <= Date.current ? "paid" : "pending"
            payment.payment_type = "credit"
            payment.payment_method = [ "pix", "bank_transfer", "cash" ].sample
            payment.received_at = payment.status == "paid" ? payment_date + rand(0..3).days : nil
          end
        end
      end
    end

    puts "✅ Created data for #{customer.name}: #{customer.appointments.count} appointments, #{customer.payments.count} payments"
  end

  puts "✅ Demo customers and data created!"
  puts "🎉 BillBuddy demo is ready!"
end
