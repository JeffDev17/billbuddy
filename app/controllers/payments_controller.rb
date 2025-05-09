# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @payments = Payment.joins(:customer).where(customers: { user_id: current_user.id })

    # Aplicar filtros
    @payments = @payments.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    @payments = @payments.where(payment_type: params[:payment_type]) if params[:payment_type].present?

    if params[:start_date].present?
      start_date = Date.parse(params[:start_date])
      @payments = @payments.where('payment_date >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.parse(params[:end_date])
      @payments = @payments.where('payment_date <= ?', end_date)
    end

    @payments = @payments.order(payment_date: :desc)
  end

  def new
    @payment = Payment.new
  end

  def create
    @payment = Payment.new(payment_params)

    if @payment.save
      # Se for um pagamento de crédito, criar um novo crédito para o cliente
      if @payment.credit?
        # Encontrar o pacote de serviço mais próximo do valor pago
        service_package = ServicePackage.active.where('price <= ?', @payment.amount).order(price: :desc).first

        if service_package
          @payment.customer.customer_credits.create(
            service_package: service_package,
            purchase_date: @payment.payment_date
          )
        end
      end

      redirect_to payments_path, notice: 'Pagamento registrado com sucesso.'
    else
      render :new
    end
  end

  private

  def payment_params
    params.require(:payment).permit(:customer_id, :payment_type, :amount, :payment_date, :notes)
  end
end