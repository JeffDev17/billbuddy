Rails.application.routes.draw do
  mount RailsAdmin::Engine => "/admin", as: "rails_admin"
  # Rota para o dashboard
  get "dashboard", to: "dashboard#index"
  root "dashboard#index"

  # Recursos principais com aninhamento
  resources :customers do
    member do
      post "debit_hours"
      post "notify_whatsapp"
      post "notify_payment_reminder"
      get :payment_reminder_form
      post :send_payment_reminder
    end
    resources :subscriptions
    resources :appointments
    resources :payments
    resources :credit_debits, only: [ :new, :create ] # Nova rota para débitos
    resources :customer_credits
    resources :extra_time_balances
  end
  devise_for :users
  resources :payments
  resources :subscriptions

  # Recursos independentes
  resources :service_packages

  # Rotas independentes para acesso global, se necessário
  resources :subscriptions, only: [ :index ]
  resources :appointments, only: [ :index ]
  resources :payments, only: [ :index ]
  resources :customer_credits, only: [ :index ]
  resources :extra_time_balances, only: [ :index ]

  # Rotas do WhatsApp
  get "whatsapp/auth", to: "whatsapp#auth"
  get "whatsapp/status", to: "whatsapp#status"
  get "whatsapp/qr-code", to: "whatsapp#qr_code"

  # Rotas do Google Calendar
  get "/google/redirect", to: "calendars#redirect", as: :redirect_calendars
  get "/google/oauth2/callback", to: "calendars#callback", as: :callback_calendars
  resources :calendars, only: [ :index ] do
    collection do
      post "create_event"
      patch "update_event/:event_id", to: "calendars#update_event", as: "update_event"
      delete "delete_event/:event_id", to: "calendars#delete_event", as: "delete_event"
      # New appointment sync routes
      post "sync_appointment/:appointment_id", to: "calendars#sync_appointment", as: "sync_appointment"
      post "bulk_sync", to: "calendars#bulk_sync"
      get "metrics", to: "calendars#metrics"
    end
  end
  get "/events/:calendar_id", to: "calendars#events", as: "events", calendar_id: /[^\/]+/
end
