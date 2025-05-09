# app/controllers/subscriptions_controller.rb
class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer
  before_action :set_subscription, only: [:edit, :update]

  def index
    @subscriptions = @customer.subscriptions.order(start_date: :desc)
  end

  def new
    @subscription = @customer.subscriptions.new(status: 'active')
  end

  def create
    @subscription = @customer.subscriptions.new(subscription_params)

    # Se já existir uma assinatura ativa, desative-a
    if @subscription.active? && @customer.active_subscription
      @customer.active_subscription.update(status: 'cancelled')
    end

    if @subscription.save
      redirect_to customer_subscriptions_path(@customer), notice: 'Assinatura criada com sucesso.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    # Se estiver ativando esta assinatura, desative outras ativas
    if subscription_params[:status] == 'active' && @subscription.status != 'active'
      @customer.subscriptions.where(status: 'active').where.not(id: @subscription.id).update_all(status: 'cancelled')
    end

    if @subscription.update(subscription_params)
      redirect_to customer_subscriptions_path(@customer), notice: 'Assinatura atualizada com sucesso.'
    else
      render :edit
    end
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:customer_id])
  end

  def set_subscription
    @subscription = @customer.subscriptions.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:amount, :start_date, :status)
  end
end