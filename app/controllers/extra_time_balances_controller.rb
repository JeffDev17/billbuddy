# app/controllers/extra_time_balances_controller.rb
class ExtraTimeBalancesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer
  before_action :set_extra_time_balance, only: [:edit, :update, :destroy]

  def index
    @extra_time_balances = @customer.extra_time_balances.order(expiry_date: :desc)
  end

  def new
    @extra_time_balance = @customer.extra_time_balances.new
  end

  def create
    @extra_time_balance = @customer.extra_time_balances.new(extra_time_balance_params)

    if @extra_time_balance.save
      redirect_to customer_extra_time_balances_path(@customer), notice: 'Saldo de tempo extra adicionado com sucesso.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @extra_time_balance.update(extra_time_balance_params)
      redirect_to customer_extra_time_balances_path(@customer), notice: 'Saldo de tempo extra atualizado com sucesso.'
    else
      render :edit
    end
  end

  def destroy
    @extra_time_balance.destroy
    redirect_to customer_extra_time_balances_path(@customer), notice: 'Saldo de tempo extra excluído com sucesso.'
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:customer_id])
  end

  def set_extra_time_balance
    @extra_time_balance = @customer.extra_time_balances.find(params[:id])
  end

  def extra_time_balance_params
    params.require(:extra_time_balance).permit(:hours, :expiry_date)
  end
end