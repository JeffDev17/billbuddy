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

ActiveRecord::Schema[7.2].define(version: 2025_09_01_141029) do
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
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_customer_id_and_scheduled_at"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["rate_source"], name: "index_appointments_on_rate_source"
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

  create_table "lesson_contents", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.string "content_type", default: "whiteboard"
    t.text "content"
    t.text "student_annotations"
    t.integer "position", default: 0
    t.boolean "visible_to_student", default: true
    t.boolean "allows_student_annotations", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id", "position"], name: "index_lesson_contents_on_lesson_id_and_position"
    t.index ["lesson_id"], name: "index_lesson_contents_on_lesson_id"
  end

  create_table "lesson_tags", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.string "tag_name", null: false
    t.string "tag_type", default: "subject"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_lesson_tags_on_lesson_id"
    t.index ["tag_name", "tag_type"], name: "index_lesson_tags_on_tag_name_and_tag_type"
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "student_id", null: false
    t.string "title"
    t.text "objectives"
    t.text "summary"
    t.string "status", default: "scheduled"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "duration_minutes"
    t.text "teacher_notes"
    t.text "homework_assigned"
    t.float "progress_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_lessons_on_appointment_id"
    t.index ["started_at"], name: "index_lessons_on_started_at"
    t.index ["status"], name: "index_lessons_on_status"
    t.index ["student_id", "status"], name: "index_lessons_on_student_id_and_status"
    t.index ["student_id", "teacher_id"], name: "index_lessons_on_student_id_and_teacher_id"
    t.index ["student_id"], name: "index_lessons_on_student_id"
    t.index ["teacher_id", "status"], name: "index_lessons_on_teacher_id_and_status"
    t.index ["teacher_id"], name: "index_lessons_on_teacher_id"
  end

  create_table "material_assignments", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.bigint "material_id", null: false
    t.boolean "required", default: false
    t.boolean "completed_by_student", default: false
    t.datetime "assigned_at"
    t.datetime "completed_at"
    t.text "student_feedback"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_material_assignments_on_lesson_id"
    t.index ["material_id"], name: "index_material_assignments_on_material_id"
  end

  create_table "materials", force: :cascade do |t|
    t.bigint "teacher_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "material_type"
    t.string "file_url"
    t.text "content"
    t.json "metadata"
    t.boolean "public", default: false
    t.string "category"
    t.string "difficulty_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["material_type", "public"], name: "index_materials_on_material_type_and_public"
    t.index ["teacher_id", "category"], name: "index_materials_on_teacher_id_and_category"
    t.index ["teacher_id"], name: "index_materials_on_teacher_id"
  end

  create_table "new_words", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.bigint "student_id", null: false
    t.bigint "teacher_id", null: false
    t.string "word"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_new_words_on_lesson_id"
    t.index ["student_id"], name: "index_new_words_on_student_id"
    t.index ["teacher_id"], name: "index_new_words_on_teacher_id"
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

  create_table "student_progresses", force: :cascade do |t|
    t.bigint "teacher_id", null: false
    t.bigint "student_id", null: false
    t.string "subject"
    t.string "topic"
    t.float "mastery_level", default: 0.0
    t.integer "lessons_count", default: 0
    t.integer "materials_completed", default: 0
    t.text "strengths"
    t.text "improvement_areas"
    t.text "teacher_notes"
    t.date "last_updated_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_student_progresses_on_student_id"
    t.index ["teacher_id", "student_id", "subject"], name: "idx_on_teacher_id_student_id_subject_59a5776b2f"
    t.index ["teacher_id"], name: "index_student_progresses_on_teacher_id"
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
  add_foreign_key "lesson_contents", "lessons"
  add_foreign_key "lesson_tags", "lessons"
  add_foreign_key "lessons", "appointments"
  add_foreign_key "lessons", "customers", column: "student_id"
  add_foreign_key "lessons", "users", column: "teacher_id"
  add_foreign_key "material_assignments", "lessons"
  add_foreign_key "material_assignments", "materials"
  add_foreign_key "materials", "users", column: "teacher_id"
  add_foreign_key "new_words", "customers", column: "student_id"
  add_foreign_key "new_words", "lessons"
  add_foreign_key "new_words", "users", column: "teacher_id"
  add_foreign_key "payments", "customers"
  add_foreign_key "student_progresses", "customers", column: "student_id"
  add_foreign_key "student_progresses", "users", column: "teacher_id"
  add_foreign_key "subscriptions", "customers"
  add_foreign_key "subscriptions", "service_packages"
end
