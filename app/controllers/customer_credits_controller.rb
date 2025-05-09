class CustomerCreditsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer

  def index
    @customer_credits = @customer.customer_credits.includes(:service_package).order(purchase_date: :desc)
  end

  def new
    @customer_credit = @customer.customer_credits.new
  end

  def create
    @customer_credit = @customer.customer_credits.new(customer_credit_params)

    if @customer_credit.save
      redirect_to customer_customer_credits_path(@customer), notice: 'Créditos adicionados com sucesso.'
    else
      render :new
    end
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:customer_id])
  end

  def customer_credit_params
    params.require(:customer_credit).permit(:service_package_id, :purchase_date)
  end
end