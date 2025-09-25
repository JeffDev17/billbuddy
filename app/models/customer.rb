require "csv"

class Customer < ApplicationRecord
  include CreditDeductible

  belongs_to :user
  has_many :customer_credits, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :extra_time_balances, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :customer_schedules, dependent: :destroy
  validates :name, presence: true
  validates :email, uniqueness: { scope: :user_id, allow_blank: true }
  validates :phone, format: {
    with: /\A\+\d{10,15}\z/,
    message: "deve estar no formato internacional (exemplo: +5519996664088 para Brasil)",
    allow_blank: true
  }
  validates :custom_hourly_rate, numericality: { greater_than: 0, allow_blank: true }
  validates :monthly_amount, numericality: { greater_than: 0, allow_blank: true }
  validates :monthly_hours, numericality: { greater_than: 0, allow_blank: true }
  before_validation :format_phone, if: :phone_changed?
  before_create :set_activated_at
  after_update :update_future_appointment_rates_if_pricing_changed

  enum status: { active: "active", inactive: "inactive", on_hold: "on_hold" }
  enum plan_type: { credit: "credit", subscription: "subscription" }
  scope :with_remaining_credits, -> { joins(:customer_credits).where("customer_credits.remaining_hours > 0").distinct }
  scope :with_active_subscriptions, -> { joins(:subscriptions).where(subscriptions: { status: "active" }).distinct }
  scope :with_upcoming_appointments, -> { joins(:appointments).where("appointments.scheduled_at > ?", Time.current).distinct }

  scope :with_birthdays, -> { where.not(birthdate: nil) }
  scope :active_during_month, ->(month_date) {
    month_end = month_date.end_of_month

    where("activated_at <= ?", month_end)
      .where("cancelled_at IS NULL OR cancelled_at > ?", month_end)
  }

  scope :with_payment_history, -> {
    joins(:payments).where("payments.status IN (?)", [ "paid", "cancelled" ]).distinct
  }

  def active_credit
    customer_credits.where("remaining_hours > 0").order(purchase_date: :desc).first
  end

  def total_remaining_hours
    customer_credits.sum(:remaining_hours)
  end

  def active_subscription
    subscriptions.where(status: "active").order(start_date: :desc).first
  end
  def unsynced_appointments
    appointments.unsynced_scheduled
  end

  def upcoming_unsynced_appointments(weeks_ahead = 4)
    unsynced_appointments.where(
      scheduled_at: Time.current..weeks_ahead.weeks.from_now
    )
  end

  def sync_status_summary
    total = appointments.scheduled.count
    synced = appointments.scheduled.where.not(google_event_id: nil).count
    {
      total: total,
      synced: synced,
      unsynced: total - synced,
      percentage: total > 0 ? (synced.to_f / total * 100).round(1) : 0
    }
  end

  def effective_hourly_rate
    return custom_hourly_rate if custom_hourly_rate.present?

    if monthly_amount.present? && monthly_hours.present? && monthly_hours > 0
      return (monthly_amount / monthly_hours)
    end

    50.0
  end

  def has_custom_pricing?
    custom_hourly_rate.present?
  end

  def monthly_total_amount
    return monthly_amount if monthly_amount.present?
    0
  end

  alias_method :package_total_value, :monthly_total_amount

  def update_future_appointment_rates!
    return unless monthly_amount.present? && monthly_hours.present?

    new_rate = effective_hourly_rate
    new_source = monthly_amount.present? && monthly_hours.present? ? "monthly_package" : "default"

    appointments
      .where(status: "scheduled")
      .where("scheduled_at >= ?", Time.current)
      .update_all(
        hourly_rate: new_rate,
        rate_source: new_source
      )
  end

  def was_active_during_month?(month_date)
    month_end = month_date.end_of_month

    return false if activated_at && activated_at > month_end

    cancelled_at.nil? || cancelled_at > month_end
  end

  def cancel!(reason: nil, cancelled_by: nil)
    update!(
      status: "inactive",
      cancelled_at: Time.current,
      cancellation_reason: reason,
      cancelled_by: cancelled_by
    )
  end

  def reactivate!(activated_by: nil)
    update!(
      status: "active",
      cancelled_at: nil,
      cancellation_reason: nil,
      cancelled_by: nil,
      activated_at: Time.current
    )
  end

  def cancellation_info
    return nil unless cancelled_at

    {
      cancelled_at: cancelled_at,
      reason: cancellation_reason,
      cancelled_by: cancelled_by,
      days_since_cancellation: (Time.current - cancelled_at).to_i / 1.day
    }
  end

  def status_history_display
    parts = []
    parts << "Ativado em #{activated_at.strftime('%d/%m/%Y')}" if activated_at

    if cancelled_at
      parts << "Cancelado em #{cancelled_at.strftime('%d/%m/%Y')}"
      parts << "Motivo: #{cancellation_reason}" if cancellation_reason.present?
    end

    parts.join(" \u2022 ")
  end

  def total_earnings
    appointments.completed.sum do |appointment|
      appointment.duration * effective_hourly_rate
    end
  end

  def earnings_for_month(month, year)
    appointments.completed
               .where(scheduled_at: Date.new(year, month, 1).beginning_of_month..Date.new(year, month, 1).end_of_month)
               .sum do |appointment|
      appointment.duration * effective_hourly_rate
    end
  end

  def total_payments
    payments.sum(:amount)
  end

  def has_regular_schedule?
    customer_schedules.enabled.exists?
  end

  def active_schedules
    customer_schedules.enabled.order(:day_of_week, :start_time)
  end

  def schedule_for_day(day_of_week)
    customer_schedules.enabled.for_day(day_of_week)
  end

  def regular_schedule_summary
    return "Sem horários regulares" unless has_regular_schedule?

    active_schedules.map(&:formatted_schedule).join(", ")
  end

  def payments_for_month(month, year)
    payments.where(payment_date: Date.new(year, month, 1).beginning_of_month..Date.new(year, month, 1).end_of_month)
            .sum(:amount)
  end

  # Bday methods
  def has_birthday?
    birthdate.present?
  end

  def birthday_this_year
    return nil unless has_birthday?
    Date.new(Date.current.year, birthdate.month, birthdate.day)
  end

  def birthday_passed_this_year?
    return false unless has_birthday?
    birthday_this_year < Date.current
  end

  def next_birthday
    return nil unless has_birthday?
    this_year_birthday = birthday_this_year

    if birthday_passed_this_year?
      Date.new(Date.current.year + 1, birthdate.month, birthdate.day)
    else
      this_year_birthday
    end
  end

  def days_until_birthday
    return nil unless has_birthday?
    next_birthday_date = next_birthday
    (next_birthday_date - Date.current).to_i
  end

  def age
    return nil unless has_birthday?
    now = Date.current
    age = now.year - birthdate.year
    age -= 1 if now < birthday_this_year
    age
  end

  def birthday_this_month?
    has_birthday? && birthdate.month == Date.current.month
  end

  def birthday_today?
    has_birthday? && birthdate.month == Date.current.month && birthdate.day == Date.current.day
  end

  def self.with_birthday_today
    with_birthdays.select { |customer| customer.birthday_today? }
  end

  def self.with_birthday_this_month(month = Date.current.month)
    with_birthdays.select { |customer| customer.birthdate.month == month }
  end

  def self.to_csv(customers)
    CSV.generate(headers: true) do |csv|
      csv << [ "nome", "email", "telefone", "status", "tipo_plano", "preco_personalizado" ]

      customers.each do |customer|
        csv << [
          customer.name,
          customer.email,
          customer.phone,
          customer.status,
          customer.plan_type,
          customer.custom_hourly_rate
        ]
      end
    end
  end

  def self.csv_template
    CSV.generate(headers: true) do |csv|
      csv << [ "nome", "email", "telefone", "status", "tipo_plano", "preco_personalizado" ]
      csv << [ "João Silva", "joao@email.com", "+5519999888777", "active", "credit", "45.00" ]
      csv << [ "Maria Santos", "maria@email.com", "+5519888777666", "active", "subscription", "" ]
      csv << [ "Pedro Oliveira", "pedro@email.com", "", "active", "credit", "40.50" ]
    end
  end

  def self.import_from_csv(file, user)
    success_count = 0
    errors = []

    CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
      row_data = {
        name: row[:nome] || row[:name],
        email: row[:email],
        phone: row[:telefone] || row[:phone],
        status: row[:status] || "active",
        plan_type: row[:tipo_plano] || row[:plan_type] || "credit",
        custom_hourly_rate: row[:preco_personalizado] || row[:custom_hourly_rate]
      }

      row_data[:phone] = nil if row_data[:phone].blank?
      row_data[:custom_hourly_rate] = nil if row_data[:custom_hourly_rate].blank?

      customer = user.customers.new(row_data)

      if customer.save
        success_count += 1
      else
        errors << "Linha #{CSV.instance_variable_get(:@lineno)}: #{row_data[:name]} - #{customer.errors.full_messages.join(', ')}"
      end
    end

    { success: success_count, errors: errors }
  end

  private

  def format_phone
    return if phone.blank?

    self.phone = phone.gsub(/[^\d+]/, "")

    unless phone.start_with?("+")
      self.phone = "+55#{phone}"
    end
  end

  def set_activated_at
    self.activated_at ||= Time.current
  end

  def update_future_appointment_rates_if_pricing_changed
    if saved_change_to_monthly_amount? || saved_change_to_monthly_hours? || saved_change_to_custom_hourly_rate?
      update_future_appointment_rates!
    end
  end
end
