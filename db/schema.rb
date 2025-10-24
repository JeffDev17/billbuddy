# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_10_03_181944) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.datetime "scheduled_at"
    t.float "duration"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "google_event_id"
    t.boolean "is_recurring_event"
    t.datetime "completed_at"
    t.decimal "hourly_rate", precision: 8, scale: 2
    t.string "rate_source"
    t.string "cancellation_type"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "reschedule_deadline"
    t.datetime "reminder_sent_at"
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_customer_id_and_scheduled_at"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["rate_source"], name: "index_appointments_on_rate_source"
    t.index ["reminder_sent_at"], name: "index_appointments_on_reminder_sent_at"
    t.index ["scheduled_at"], name: "index_appointments_on_scheduled_at"
    t.index ["status"], name: "index_appointments_on_status"
  end

  create_table "customer_credits", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "service_package_id", null: false
    t.float "remaining_hours"
    t.datetime "purchase_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_credits_on_customer_id"
    t.index ["service_package_id"], name: "index_customer_credits_on_service_package_id"
  end

  create_table "customer_schedules", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.integer "day_of_week"
    t.time "start_time"
    t.decimal "duration"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_schedules_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "status"
    t.string "plan_type"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "custom_hourly_rate"
    t.decimal "monthly_amount"
    t.decimal "monthly_hours"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.string "cancelled_by"
    t.datetime "activated_at"
    t.date "birthdate"
    t.index ["activated_at"], name: "index_customers_on_activated_at"
    t.index ["cancelled_at"], name: "index_customers_on_cancelled_at"
    t.index ["status", "cancelled_at"], name: "index_customers_on_status_and_cancelled_at"
    t.index ["status", "created_at"], name: "index_customers_on_status_and_created_at"
    t.index ["status"], name: "index_customers_on_status"
    t.index ["user_id", "status"], name: "index_customers_on_user_id_and_status"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "extra_time_balances", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.float "hours"
    t.date "expiry_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_extra_time_balances_on_customer_id"
  end

  create_table "failed_notifications", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "notification_type", null: false
    t.text "error_message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "notification_type"], name: "index_failed_notifications_on_customer_id_and_notification_type"
    t.index ["customer_id"], name: "index_failed_notifications_on_customer_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "payment_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.date "payment_date", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.string "payment_method"
    t.string "transaction_reference"
    t.datetime "received_at"
    t.string "processed_by"
    t.string "bank_name"
    t.integer "installments", default: 1
    t.decimal "fees", precision: 10, scale: 2, default: "0.0"
    t.index ["customer_id", "payment_date"], name: "index_payments_on_customer_id_and_payment_date"
    t.index ["customer_id", "status"], name: "index_payments_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_payments_on_customer_id"
    t.index ["payment_method"], name: "index_payments_on_payment_method"
    t.index ["received_at"], name: "index_payments_on_received_at"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["transaction_reference"], name: "index_payments_on_transaction_reference"
  end

  create_table "service_packages", force: :cascade do |t|
    t.string "name"
    t.integer "hours"
    t.decimal "price"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.decimal "amount"
    t.date "start_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "service_package_id", null: false
    t.date "end_date"
    t.integer "billing_day"
    t.text "notes"
    t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
    t.index ["service_package_id"], name: "index_subscriptions_on_service_package_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "google_calendar_token"
    t.string "google_calendar_refresh_token"
    t.datetime "google_calendar_expires_at"
    t.boolean "appointment_reminders_enabled", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "appointments", "customers"
  add_foreign_key "customer_credits", "customers"
  add_foreign_key "customer_credits", "service_packages"
  add_foreign_key "customer_schedules", "customers"
  add_foreign_key "customers", "users"
  add_foreign_key "extra_time_balances", "customers"
  add_foreign_key "failed_notifications", "customers"
  add_foreign_key "payments", "customers"
  add_foreign_key "subscriptions", "customers"
  add_foreign_key "subscriptions", "service_packages"
end
