class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [:show, :edit, :update, :destroy]

  def index
    @subscriptions = Subscription.all
  end

  def show
  end

  def new
    @subscription = Subscription.new
  end

  def edit
  end

  def create
    @subscription = Subscription.new(subscription_params)

    if @subscription.save
      redirect_to @subscription, notice: 'Assinatura criada com sucesso.'
    else
      render :new
    end
  end

  def update
    if @subscription.update(subscription_params)
      redirect_to @subscription, notice: 'Assinatura atualizada com sucesso.'
    else
      render :edit
    end
  end

  def destroy
    @subscription.destroy
    redirect_to subscriptions_path, notice: 'Assinatura excluída com sucesso.'
  end

  private
  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:customer_id, :service_package_id, :start_date, :end_date, :billing_day, :status, :notes)
  end
end