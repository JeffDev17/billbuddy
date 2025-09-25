class SubscriptionsController < ApplicationController
  include UserScoped

  before_action :authenticate_user!
  before_action :set_customer, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_subscription, only: [ :show, :edit, :update, :destroy ]

  def index
    if params[:customer_id]
      # Nested route: /customers/:customer_id/subscriptions
      @customer = current_user.customers.find(params[:customer_id])
      @subscriptions = @customer.subscriptions.order(created_at: :desc)
    else
      # Standalone route: /subscriptions
      @subscriptions = Subscription.joins(:customer).where(customers: { user_id: current_user.id }).order(created_at: :desc)
    end
  end

  def show
  end

  def new
    @subscription = @customer.subscriptions.build
    @subscription.start_date = Date.current
    @subscription.status = "active"
  end

  def edit
  end

  def create
    @subscription = @customer.subscriptions.build(subscription_params)

    if @subscription.save
      redirect_to @customer, notice: "Assinatura criada com sucesso."
    else
      render :new
    end
  end

  def update
    if @subscription.update(subscription_params)
      redirect_to @customer, notice: "Assinatura atualizada com sucesso."
    else
      render :edit
    end
  end

  def destroy
    @subscription.destroy
    redirect_to @customer, notice: "Assinatura exclu\u00EDda com sucesso."
  end

  private

  def set_customer
    @customer = current_user.customers.find(params[:customer_id])
  end

  def set_subscription
    if params[:customer_id]
      @customer = current_user.customers.find(params[:customer_id]) unless @customer
      @subscription = @customer.subscriptions.find(params[:id])
    else
      @subscription = Subscription.joins(:customer).where(customers: { user_id: current_user.id }).find(params[:id])
    end
  end

  def subscription_params
    params.require(:subscription).permit(:service_package_id, :start_date, :end_date, :billing_day, :status, :notes, :amount)
  end
end
