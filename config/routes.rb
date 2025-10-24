Rails.application.routes.draw do
  mount RailsAdmin::Engine => "/admin", as: "rails_admin"

  get "dashboard", to: "dashboard#index"
  root "dashboard#index"

  get "chat", to: "chat#index"
  post "chat/send_message", to: "chat#send_message"
  get "chat/weekly_insight", to: "chat#weekly_insight"

  resources :customers do
    collection do
      get :import_csv
      post :process_csv_import
      get :export_csv
      get :download_template
      get :bulk_message_form
      post :send_bulk_message
    end
    member do
      post "debit_hours"
      # post "notify_whatsapp"  # WhatsApp desativado
      post "notify_payment_reminder"
      get :payment_reminder_form
      post :send_payment_reminder
      post "sync_appointments"
      post "sync_upcoming_appointments"
    end
    resources :subscriptions
    resources :payments, except: [ :show ] do
      collection do
        get :history, to: "payments#history", as: "payment_history"
      end
    end
    resources :credit_debits, only: [ :new, :create ]
    resources :customer_credits
    resources :extra_time_balances
  end


  # Zero registro de novos usuários
  devise_for :users, skip: [ :registrations ]

  # Profile management routes
  get "profile", to: "profile#show"
  get "profile/edit", to: "profile#edit"
  patch "profile", to: "profile#update"
  get "profile/change-password", to: "profile#change_password", as: "change_password"
  patch "profile/change-password", to: "profile#update_password", as: "update_password"

  resources :payments do
    collection do
      get :monthly_checklist
      post :mark_paid
      post :unmark_paid
      post :update_payment_status
      post :update_payment_amount
      post :bulk_mark_paid
    end
  end
  resources :subscriptions

  resources :subscriptions, only: [ :index ]
  resources :appointments, except: [ :show ] do
    collection do
      delete "bulk_delete_by_customer/:customer_id", to: "appointments#bulk_delete_by_customer", as: "bulk_delete_by_customer"
      post "bulk_mark_completed", to: "appointments#bulk_mark_completed"
      get "review_sync"
      post "confirm_sync"
      post "sync_all_appointments"
      post "sync_upcoming_appointments"
      get "manage_auto_generation"
      post "setup_auto_generation"
      post "cancel_auto_generation"
      post "run_auto_generation_now"

      # New unified system routes
      post "fill_current_month", to: "appointments#fill_current_month"
      get "preview_current_month", to: "appointments#preview_current_month"
      post "generate_next_month", to: "appointments#generate_next_month"
      get "preview_next_month", to: "appointments#preview_next_month"
      post "preview_next_month", to: "appointments#preview_next_month"
      post "generate_custom_period", to: "appointments#generate_custom_period"
      get "get_month_stats", to: "appointments#get_month_stats"
      delete "delete_month_appointments", to: "appointments#delete_month_appointments"
      post "generate_specific_month", to: "appointments#generate_specific_month"

      get "preview_generation"
      post "confirm_generation"
    end
    member do
      post "mark_completed", to: "appointments#mark_completed"
      get "cancellation_options", to: "appointments#cancellation_options"
      post "mark_cancelled", to: "appointments#mark_cancelled"
      post "reschedule", to: "appointments#reschedule"
    end
  end
  resources :payments, only: [ :index ]
  resources :customer_credits, only: [ :index ]
  resources :extra_time_balances, only: [ :index ]
  resources :customer_schedules, only: [ :create, :update, :destroy ]

  # WhatsApp desativado temporariamente
  # get "whatsapp/auth", to: "whatsapp#auth"
  # get "whatsapp/status", to: "whatsapp#status"
  # get "whatsapp/qr-code", to: "whatsapp#qr_code"
  # post "whatsapp/start", to: "whatsapp#start_service"
  # post "whatsapp/stop", to: "whatsapp#stop_service"
  # post "whatsapp/restart", to: "whatsapp#restart_service"
  # post "whatsapp/toggle-reminders", to: "whatsapp#toggle_reminders"
  # get "whatsapp/reminder-stats", to: "whatsapp#reminder_stats"
  # post "whatsapp/send-reminder/:appointment_id", to: "whatsapp#send_reminder_for_appointment"

  get "/google/redirect", to: "calendars#redirect", as: :redirect_calendars
  get "/google/oauth2/callback", to: "calendars#callback", as: :callback_calendars
  resources :calendars, only: [ :index ] do
    collection do
      get "redirect"
      get "callback"
      get :daily_completion
      post :sync_calendar
      delete :clear_events
      get "events", to: "calendars#fullcalendar_events", as: "events"

      post "sync_appointment/:appointment_id", to: "calendars#sync_appointment", as: "sync_appointment"
      post "bulk_sync", to: "calendars#bulk_sync"
      post "sync_customer_recurring/:customer_id", to: "calendars#sync_customer_recurring", as: "sync_customer_recurring"

      # New Smart Sync routes
      post "smart_sync_current_month", to: "calendars#smart_sync_current_month"
      post "smart_sync_next_month", to: "calendars#smart_sync_next_month"
      post "smart_sync_custom_month", to: "calendars#smart_sync_custom_month"

      get "metrics", to: "calendars#metrics"
    end
  end
  get "/events/:calendar_id", to: "calendars#events", as: "events", calendar_id: /[^\/]+/

  # Silence Chrome DevTools request in development
  get "/.well-known/appspecific/com.chrome.devtools.json" => proc { [ 204, {}, [] ] } if Rails.env.development?

  # PWA routes
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
