Rails.application.routes.draw do
  devise_for :users

  # Rota raiz
  root 'dashboard#index'

  # Rotas de recursos
  resources :customers do
    resources :customer_credits, only: [:index, :new, :create]
    resources :subscriptions, only: [:index, :new, :create, :edit, :update]
    resources :appointments, only: [:index, :new, :create]
    resources :extra_time_balances, only: [:index]
  end

  resources :service_packages
  resources :appointments, only: [:index, :edit, :update, :destroy]
  resources :payments, only: [:index, :new, :create]

  # Dashboard
  get 'dashboard', to: 'dashboard#index'
end