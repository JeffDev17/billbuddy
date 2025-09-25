# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  include UserScoped

  before_action :authenticate_user!
  before_action :set_customer, only: [ :new, :create, :edit, :update, :destroy, :history ]
  before_action :set_payment, only: [ :edit, :update, :destroy ]

  def index
    @payments = payment_management_service.filter_payments(params)
    @show_customer_column = true
  end

  def new
    @payment = @customer.payments.build
    # Set defaults
    @payment.payment_date = Date.current
    @payment.payment_type = @customer.plan_type if @customer.plan_type.in?([ "subscription", "credit" ])
  end

  def create
    @payment = @customer.payments.build(payment_params)

    if @payment.save
      # Mark as paid automatically if received_at is set
      if @payment.received_at.present? && @payment.status == "pending"
        @payment.mark_as_paid!(processed_by: current_user.email)
      end

      redirect_to customer_payments_path(@customer), notice: "Pagamento registrado com sucesso."
    else
      render :new
    end
  end

  def edit
    # Allow editing with a warning for past months
    if @payment.payment_date < Date.current.beginning_of_month
      flash.now[:warning] = "⚠️ Você está editando um pagamento de mês anterior. Tenha cuidado para manter a integridade dos dados históricos."
    end
  end

  def update
    if @payment.update(payment_params)
      # Mark as paid automatically if received_at is set and status is pending
      if @payment.received_at.present? && @payment.status == "pending"
        @payment.mark_as_paid!(processed_by: current_user.email)
      end

      redirect_to customer_payments_path(@customer), notice: "Pagamento atualizado com sucesso."
    else
      render :edit
    end
  end

  def destroy
    payment_date = @payment.payment_date
    payment_amount = @payment.amount
    @payment.destroy

    # Determine where to redirect based on referer or default to history
    redirect_path = if request.referer&.include?("history")
                      payment_history_customer_payments_path(@customer)
    else
                      customer_payments_path(@customer)
    end

    # Show warning if deleting past month payment
    formatted_amount = "%.2f" % payment_amount
    if payment_date < Date.current.beginning_of_month
      redirect_to redirect_path,
                  notice: "⚠️ Pagamento de R$ #{formatted_amount} excluído. Verifique se isso não afeta seus relatórios históricos."
    else
      redirect_to redirect_path,
                  notice: "Pagamento de R$ #{formatted_amount} excluído com sucesso."
    end
  end

  # Payment history for a specific customer
  def history
    @payments = @customer.payments
                        .recent_first
                        .page(params[:page])
                        .per(20)

    # Group by month for better organization
    @payments_by_month = @payments.group_by { |payment| payment.payment_date.beginning_of_month }

    # Calculate totals
    @total_paid = @customer.payments.paid_payments.sum(:amount)
    @total_fees = @customer.payments.paid_payments.sum(:fees)
    @net_total = @total_paid - @total_fees

    # Payment method breakdown
    @payment_methods_summary = @customer.payments.paid_payments
                                       .group(:payment_method)
                                       .sum(:amount)
  end

  # Monthly checklist for payments (enhanced to allow past month editing)
  def monthly_checklist
    @selected_month = params[:month] || Date.current.strftime("%Y-%m")
    @sort_by = params[:sort_by] || "name"
    checklist_data = payment_management_service.monthly_checklist_data(@selected_month, @sort_by)

    @month_date = checklist_data[:month_date]
    @is_past_month = checklist_data[:is_past_month]
    @is_current_or_future_month = checklist_data[:is_current_or_future_month]
    @customers = checklist_data[:customers]
    @payments_by_customer = checklist_data[:payments_by_customer]

    assign_financial_totals(checklist_data[:financial_totals])
  end

  # Update payment status via AJAX (enhanced to allow past month with warning)
  def update_payment_status
    customer = find_customer(params[:customer_id])
    month_date = Date.parse("#{params[:month]}-01")

    # Allow past month editing but with audit trail
    if month_date < Date.current.beginning_of_month
      Rails.logger.warn "Past month payment edit: User #{current_user.email} editing payment for #{customer.name} in #{params[:month]}"
    end

    result = payment_management_service.update_payment_status(customer, params[:month], params[:status], allow_past_month: true)

    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "Cliente não encontrado" }
  end

  # Mark payment as paid via AJAX (enhanced)
  def mark_paid
    customer = find_customer(params[:customer_id])
    month_date = Date.parse("#{params[:month]}-01")

    # Allow past month editing but with audit trail
    if month_date < Date.current.beginning_of_month
      Rails.logger.warn "Past month payment mark as paid: User #{current_user.email} marking payment for #{customer.name} in #{params[:month]}"
    end

    result = payment_management_service.mark_payment_paid(customer, params[:month], allow_past_month: true, processed_by: current_user.email)

    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "Cliente não encontrado" }
  end

  # Unmark payment as paid via AJAX (enhanced)
  def unmark_paid
    customer = find_customer(params[:customer_id])
    month_date = Date.parse("#{params[:month]}-01")

    # Allow past month editing but with audit trail
    if month_date < Date.current.beginning_of_month
      Rails.logger.warn "Past month payment unmark: User #{current_user.email} unmarking payment for #{customer.name} in #{params[:month]}"
    end

    result = payment_management_service.unmark_payment_paid(customer, params[:month], allow_past_month: true)

    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "Cliente não encontrado" }
  end

  # Update payment amount via AJAX for inline editing
  def update_payment_amount
    customer = find_customer(params[:customer_id])
    month_string = params[:month]
    new_amount = params[:amount].to_f

    if new_amount <= 0
      render json: { success: false, message: "Valor deve ser maior que zero" }
      return
    end

    month_date = Date.parse("#{month_string}-01")
    payment_type = customer.plan_type
    payment = payment_management_service.send(:find_existing_payment, customer, month_date, payment_type)
    calculated_amount = customer.package_total_value

    if payment
      # Update existing payment amount
      if payment.update(amount: new_amount)
        render json: {
          success: true,
          amount: new_amount,
          is_manual_override: (new_amount != calculated_amount)
        }
      else
        render json: { success: false, message: "Erro ao atualizar pagamento" }
      end
    else
      # Create new payment with custom amount
      payment = customer.payments.build(
        payment_type: payment_type,
        payment_date: month_date,
        payment_method: "pix",
        amount: new_amount,
        status: "pending",
        notes: new_amount != calculated_amount ? "Valor personalizado - #{month_date.strftime('%B %Y')}" : "Pagamento mensal - #{month_date.strftime('%B %Y')}"
      )

      if payment.save
        render json: {
          success: true,
          amount: new_amount,
          payment_id: payment.id,
          is_manual_override: (new_amount != calculated_amount)
        }
      else
        render json: { success: false, message: "Erro ao criar pagamento" }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "Cliente não encontrado" }
  rescue => e
    Rails.logger.error "Update payment amount error: #{e.message}"
    render json: { success: false, message: "Erro interno do servidor" }
  end

  # Bulk mark payments as paid via AJAX (enhanced)
  def bulk_mark_paid
    customer_ids = params[:customer_ids] || []
    month = params[:month]

    if customer_ids.empty?
      render json: { success: false, message: "Nenhum cliente selecionado" }
      return
    end

    if month.blank?
      render json: { success: false, message: "Mês não especificado" }
      return
    end

    # Check if it's a past month and warn
    month_date = Date.parse("#{month}-01")
    if month_date < Date.current.beginning_of_month
      Rails.logger.warn "Bulk past month payment marking: User #{current_user.email} bulk marking payments for #{customer_ids.length} customers in #{month}"
    end

    result = payment_management_service.bulk_mark_payments_paid(customer_ids, month, allow_past_month: true, processed_by: current_user.email)

    if result.is_a?(Hash) && result[:success]
      render json: {
        success: true,
        message: "#{result[:success].length} pagamento(s) processado(s) com sucesso",
        total_amount: result[:total_amount],
        failed_count: result[:failed].length,
        is_past_month: month_date < Date.current.beginning_of_month
      }
    else
      render json: result
    end
  rescue => e
    Rails.logger.error "Bulk mark paid error: #{e.message}"
    render json: { success: false, message: "Erro interno do servidor" }
  end

  private

  def set_customer
    return unless params[:customer_id]
    @customer = find_customer(params[:customer_id])
  end

  def set_payment
    @payment = @customer.payments.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(
      :payment_type, :amount, :payment_date, :notes, :status,
      :payment_method, :transaction_reference, :received_at,
      :bank_name, :installments, :fees
    )
  end

  def payment_management_service
    @payment_management_service ||= PaymentManagementService.new(current_user)
  end

  def assign_financial_totals(totals)
    @total_received = totals[:total_received] || 0
    @total_cancelled = totals[:cancelled_amount] || 0
    @total_pending = totals[:pending_amount] || 0
    @total_expected = totals[:total_expected] || 0

    # Calculate subscription totals
    subscription_customers = @customers.select { |customer| customer.plan_type == "subscription" }
    @subscription_expected = subscription_customers.sum(&:package_total_value)
    @subscription_received = @payments_by_customer.select { |customer_id, payments|
      subscription_customers.any? { |customer| customer.id == customer_id } && payments.any?(&:paid?)
    }.values.flatten.select(&:paid?).sum(&:amount)

    # Calculate credit totals
    credit_customers = @customers.select { |customer| customer.plan_type == "credit" }
    @credit_expected = credit_customers.sum(&:package_total_value)
    @credit_received = @payments_by_customer.select { |customer_id, payments|
      credit_customers.any? { |customer| customer.id == customer_id } && payments.any?(&:paid?)
    }.values.flatten.select(&:paid?).sum(&:amount)
  end
end
