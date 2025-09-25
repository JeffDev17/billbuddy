# Service to handle payment management and calculations
class PaymentManagementService
  def initialize(user)
    @user = user
  end

  def filter_payments(params = {})
    payments = base_payments_scope

    payments = filter_by_customer(payments, params[:customer_id])
    payments = filter_by_type(payments, params[:payment_type])
    payments = filter_by_payment_method(payments, params[:payment_method])
    payments = filter_by_status(payments, params[:status])
    payments = filter_by_date_range(payments, params[:start_date], params[:end_date])

    payments.order(payment_date: :desc, created_at: :desc)
  end

  def monthly_checklist_data(month_string, sort_by = "name")
    month_date = Date.parse("#{month_string}-01")
    customers = eligible_customers_for_month(month_date)
    payments_by_customer = payments_for_month(month_date)

    # Sort customers based on the sort_by parameter
    sorted_customers = sort_customers_by_payment_status(customers, payments_by_customer, sort_by)

    {
      month_date: month_date,
      is_past_month: month_date < Date.current.beginning_of_month,
      is_current_or_future_month: month_date >= Date.current.beginning_of_month,
      customers: sorted_customers,
      payments_by_customer: payments_by_customer,
      financial_totals: calculate_monthly_totals(month_date)
    }
  end

  # Enhanced to allow past month editing with audit trail
  def update_payment_status(customer, month_string, new_status, allow_past_month: false, processed_by: nil)
    return failure_result("Status inválido") unless valid_status?(new_status)

    month_date = Date.parse("#{month_string}-01")

    # Check past month restriction if not explicitly allowed
    if !allow_past_month && month_date < Date.current.beginning_of_month
      return failure_result("Não é possível alterar pagamentos de meses passados")
    end

    payment_type = customer.plan_type
    payment = find_existing_payment(customer, month_date, payment_type)

    if payment
      # Update existing payment
      previous_status = payment.status
      if payment.update(status: new_status, processed_by: processed_by)
        # Set received_at when marking as paid
        if new_status == "paid" && previous_status != "paid"
          payment.update(received_at: Time.current)
        elsif new_status != "paid"
          payment.update(received_at: nil)
        end

        # Log past month changes
        if month_date < Date.current.beginning_of_month
          Rails.logger.info "Past month payment status change: Customer #{customer.name} (#{customer.id}) - #{previous_status} → #{new_status} in #{month_string} by #{processed_by}"
        end

        success_result(new_status, payment.amount, payment.id)
      else
        failure_result("Erro ao atualizar pagamento: #{payment.errors.full_messages.join(', ')}")
      end
    else
      # Create new payment
      payment = build_new_payment(customer, month_date, payment_type)
      payment.status = new_status
      payment.amount = calculate_payment_amount(customer, month_date)
      payment.processed_by = processed_by

      # Set received_at if marking as paid
      if new_status == "paid"
        payment.received_at = Time.current
      end

      if payment.save
        # Log past month creation
        if month_date < Date.current.beginning_of_month
          Rails.logger.info "Past month payment creation: Customer #{customer.name} (#{customer.id}) - new payment with status #{new_status} in #{month_string} by #{processed_by}"
        end

        success_result(new_status, payment.amount, payment.id)
      else
        failure_result("Erro ao criar pagamento: #{payment.errors.full_messages.join(', ')}")
      end
    end
  rescue => e
    Rails.logger.error "Payment status update error: #{e.message}"
    failure_result("Erro interno do servidor")
  end

  # Enhanced to allow past month editing
  def mark_payment_paid(customer, month_string, allow_past_month: false, processed_by: nil)
    month_date = Date.parse("#{month_string}-01")

    # Check past month restriction if not explicitly allowed
    if !allow_past_month && month_date < Date.current.beginning_of_month
      return failure_result("Não é possível alterar pagamentos de meses passados")
    end

    payment_type = customer.plan_type
    payment = find_existing_payment(customer, month_date, payment_type)

    if payment
      if payment.update(status: "paid", received_at: Time.current, processed_by: processed_by)
        # Log past month changes
        if month_date < Date.current.beginning_of_month
          Rails.logger.info "Past month payment marked as paid: Customer #{customer.name} (#{customer.id}) in #{month_string} by #{processed_by}"
        end

        success_result("paid", payment.amount, payment.id)
      else
        failure_result("Erro ao marcar pagamento como pago")
      end
    else
      payment = build_new_payment(customer, month_date, payment_type)
      payment.status = "paid"
      payment.amount = calculate_payment_amount(customer, month_date)
      payment.received_at = Time.current
      payment.processed_by = processed_by

      if payment.save
        # Log past month creation
        if month_date < Date.current.beginning_of_month
          Rails.logger.info "Past month payment created as paid: Customer #{customer.name} (#{customer.id}) in #{month_string} by #{processed_by}"
        end

        success_result("paid", payment.amount, payment.id)
      else
        failure_result("Erro ao criar pagamento")
      end
    end
  end

  # Enhanced to allow past month editing
  def unmark_payment_paid(customer, month_string, allow_past_month: false)
    month_date = Date.parse("#{month_string}-01")

    # Check past month restriction if not explicitly allowed
    if !allow_past_month && month_date < Date.current.beginning_of_month
      return failure_result("Não é possível alterar pagamentos de meses passados")
    end

    payment_type = customer.plan_type
    payment = find_existing_payment(customer, month_date, payment_type)

    if payment && payment.paid?
      if payment.update(status: "pending", received_at: nil, processed_by: nil)
        # Log past month changes
        if month_date < Date.current.beginning_of_month
          Rails.logger.info "Past month payment unmarked: Customer #{customer.name} (#{customer.id}) in #{month_string}"
        end

        success_result("pending", payment.amount, payment.id)
      else
        failure_result("Erro ao desmarcar pagamento")
      end
    else
      failure_result("Pagamento não encontrado ou não está marcado como pago")
    end
  end

  # Enhanced bulk operation with past month support
  def bulk_mark_payments_paid(customer_ids, month_string, allow_past_month: false, processed_by: nil)
    month_date = Date.parse("#{month_string}-01")

    # Check past month restriction if not explicitly allowed
    if !allow_past_month && month_date < Date.current.beginning_of_month
      return failure_result("Não é possível alterar pagamentos de meses passados")
    end

    results = { success: [], failed: [], total_amount: 0 }

    customer_ids.each do |customer_id|
      customer = @user.customers.find_by(id: customer_id)
      next unless customer

      result = mark_payment_paid(customer, month_string, allow_past_month: true, processed_by: processed_by)
      if result[:success]
        results[:success] << customer.name
        results[:total_amount] += result[:amount]
      else
        results[:failed] << "#{customer.name}: #{result[:message]}"
      end
    end

    # Log bulk past month operations
    if month_date < Date.current.beginning_of_month && !results[:success].empty?
      Rails.logger.info "Bulk past month payment marking: #{results[:success].length} payments marked for #{month_string} by #{processed_by}"
    end

    results
  rescue => e
    Rails.logger.error "Bulk mark payments error: #{e.message}"
    failure_result("Erro interno do servidor")
  end

  private

  def base_payments_scope
    Payment.joins(:customer)
           .where(customers: { user_id: @user.id })
           .includes(:customer)
  end

  def filter_by_customer(payments, customer_id)
    return payments if customer_id.blank?
    payments.where(customer_id: customer_id)
  end

  def filter_by_type(payments, payment_type)
    return payments if payment_type.blank?
    payments.where(payment_type: payment_type)
  end

  def filter_by_payment_method(payments, payment_method)
    return payments if payment_method.blank?
    payments.where(payment_method: payment_method)
  end

  def filter_by_status(payments, status)
    return payments if status.blank?
    payments.where(status: status)
  end

  def filter_by_date_range(payments, start_date, end_date)
    payments = filter_by_start_date(payments, start_date)
    filter_by_end_date(payments, end_date)
  end

  def filter_by_start_date(payments, start_date)
    return payments if start_date.blank?
    payments.where("payment_date >= ?", start_date)
  end

  def filter_by_end_date(payments, end_date)
    return payments if end_date.blank?
    payments.where("payment_date <= ?", end_date)
  end

  # FIXED: Improved customer eligibility with proper historical tracking
  def eligible_customers_for_month(month_date)
    current_month = Date.current.beginning_of_month

    if month_date < current_month
      # For past months, show customers who were ACTIVE during that month
      # This ensures proper historical accuracy regardless of current status
      historical_customers_for_month(month_date)
    elsif month_date == current_month
      # For current month, show active customers + customers with existing payments
      # This handles cases where customers canceled but have payments for this month
      current_month_customers(month_date)
    else
      # For future months, show only currently active customers
      @user.customers.active
           .where(plan_type: [ "subscription", "credit" ])
           .order(:name)
    end
  end

  # NEW: Get customers who were active during a specific historical month
  def historical_customers_for_month(month_date)
    # Get customers who were active during that month (using new tracking)
    historically_active = @user.customers
                               .active_during_month(month_date)
                               .where(plan_type: [ "subscription", "credit" ])

    # Also include customers who have payment records for that month
    # (this handles cases where tracking might be incomplete)
    customer_ids_with_payments = payments_for_month(month_date).keys

    # Combine both sets for comprehensive historical accuracy
    all_relevant_customer_ids = (
      historically_active.pluck(:id) + customer_ids_with_payments
    ).uniq

    @user.customers.where(id: all_relevant_customer_ids)
         .where(plan_type: [ "subscription", "credit" ])
         .order(:name)
  end

  # NEW: Get customers for current month (active + those with existing payments)
  def current_month_customers(month_date)
    # Get currently active customers
    currently_active = @user.customers.active
                            .where(plan_type: [ "subscription", "credit" ])

    # Also include customers who have payment records for this month
    # (handles cases where customers canceled but have payments for this month)
    customer_ids_with_payments = payments_for_month(month_date).keys

    # Combine both sets for comprehensive current month management
    all_relevant_customer_ids = (
      currently_active.pluck(:id) + customer_ids_with_payments
    ).uniq

    @user.customers.where(id: all_relevant_customer_ids)
         .where(plan_type: [ "subscription", "credit" ])
         .order(:name)
  end

  def eligible_customers
    @user.customers.active
         .where(plan_type: [ "subscription", "credit" ])
         .order(:name)
  end

  def payments_for_month(month_date)
    month_start = month_date.beginning_of_month
    month_end = month_date.end_of_month

    base_payments_scope
      .where(payment_date: month_start..month_end)
      .where(payment_type: [ "subscription", "credit" ])
      .group_by(&:customer_id)
  end

  def calculate_monthly_totals(month_date)
    payments = payments_for_month(month_date).values.flatten

    # Calculate expected amount based on actual payments or customer pricing
    total_expected = calculate_total_expected_amount(month_date)
    total_paid = payments.select(&:paid?).sum(&:amount)
    total_cancelled = payments.select(&:cancelled?).sum(&:amount)
    total_pending = payments.select { |p| p.pending? }.sum(&:amount)

    {
      total_expected: total_expected,
      total_received: total_paid,
      pending_amount: total_pending,
      cancelled_amount: total_cancelled
    }
  end

  def calculate_pending_amount(month_date)
    # Calculate based on actual pending payment records
    payments_for_month(month_date).values.flatten.select(&:pending?).sum(&:amount)
  end

  private

  def calculate_total_expected_amount(month_date)
    total = 0
    eligible_customers_for_month(month_date).each do |customer|
      payments = payments_for_month(month_date)[customer.id]
      if payments&.any?
        # Use actual payment amount if exists
        total += payments.first.amount
      else
        # Use calculated amount for customers without payments
        total += calculate_payment_amount(customer, month_date)
      end
    end
    total
  end

  def valid_status?(status)
    %w[pending paid cancelled].include?(status)
  end

  def find_existing_payment(customer, month_date, payment_type)
    customer.payments
            .where(payment_date: month_date.beginning_of_month..month_date.end_of_month)
            .where(payment_type: payment_type)
            .first
  end

  def build_new_payment(customer, month_date, payment_type)
    customer.payments.build(
      payment_type: payment_type,
      payment_date: month_date,
      payment_method: "pix", # Default to PIX
      notes: "Pagamento mensal - #{month_date.strftime('%B %Y')}"
    )
  end

  def calculate_payment_amount(customer, month_date)
    customer.package_total_value
  end

  def success_result(status, amount, payment_id = nil)
    result = { success: true, status: status, amount: amount }
    result[:payment_id] = payment_id if payment_id
    result
  end

  def failure_result(message)
    { success: false, message: message }
  end

  def sort_customers_by_payment_status(customers, payments_by_customer, sort_by)
    case sort_by
    when "payment_status"
      # Sort by payment status: paid first, then cancelled, then pending
      customers.sort_by do |customer|
        payment = payments_by_customer[customer.id]&.first
        status = payment&.status || "pending"
        status_priority = { "paid" => 1, "cancelled" => 2, "pending" => 3 }
        [ status_priority[status] || 4, customer.name.downcase ]
      end
    when "payment_status_reverse"
      # Sort by payment status: pending first, then cancelled, then paid
      customers.sort_by do |customer|
        payment = payments_by_customer[customer.id]&.first
        status = payment&.status || "pending"
        status_priority = { "pending" => 1, "cancelled" => 2, "paid" => 3 }
        [ status_priority[status] || 4, customer.name.downcase ]
      end
    when "plan_type"
      # Sort by plan type: subscription first, then credit
      customers.sort_by do |customer|
        plan_priority = { "subscription" => 1, "credit" => 2 }
        [ plan_priority[customer.plan_type] || 3, customer.name.downcase ]
      end
    when "package_value"
      # Sort by package value: highest first
      customers.sort_by { |customer| [ -customer.package_total_value, customer.name.downcase ] }
    when "package_value_asc"
      # Sort by package value: lowest first
      customers.sort_by { |customer| [ customer.package_total_value, customer.name.downcase ] }
    else
      # Default: sort by name
      customers.order(:name)
    end
  end
end
