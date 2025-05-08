class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    @customers = current_user.customers.order(name: :asc)
  end

  def show
    @active_credit = @customer.active_credit
    @active_subscription = @customer.active_subscription
    @upcoming_appointments = @customer.appointments.where('scheduled_at > ?', Time.current).order(scheduled_at: :asc).limit(5)
    @extra_time_balances = @customer.extra_time_balances.valid
  end

  def new
    @customer = current_user.customers.new
  end

  def create
    @customer = current_user.customers.new(customer_params)

    if @customer.save
      redirect_to @customer, notice: 'Cliente criado com sucesso.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: 'Cliente atualizado com sucesso.'
    else
      render :edit
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: 'Cliente excluído com sucesso.'
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :status, :plan_type)
  end
end