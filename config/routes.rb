Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  # Rota para o dashboard
  get 'dashboard', to: 'dashboard#index'
  root 'dashboard#index'

  # Recursos principais com aninhamento
  resources :customers do
    member do
      post 'debit_hours'
      post 'notify_whatsapp'
      post 'notify_payment_reminder'
      get :payment_reminder_form
      post :send_payment_reminder
    end
    resources :subscriptions
    resources :appointments
    resources :payments
    resources :credit_debits, only: [:new, :create] # Nova rota para débitos
    resources :customer_credits
    resources :extra_time_balances
  end
  devise_for :users
  resources :payments
  resources :subscriptions

  # Recursos independentes
  resources :service_packages

  # Rotas independentes para acesso global, se necessário
  resources :subscriptions, only: [:index]
  resources :appointments, only: [:index]
  resources :payments, only: [:index]
  resources :customer_credits, only: [:index]
  resources :extra_time_balances, only: [:index]

  # Rotas do WhatsApp
  get 'whatsapp/auth', to: 'whatsapp#auth'
  get 'whatsapp/status', to: 'whatsapp#status'
  get 'whatsapp/qr-code', to: 'whatsapp#qr_code'

  # Outras rotas personalizadas, se necessário
end