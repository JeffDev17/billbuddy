require "csv"

class Customer < ApplicationRecord
  include CreditDeductible

  # Relacionamentos
  belongs_to :user
  has_many :customer_credits, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :extra_time_balances, dependent: :destroy
  has_many :payments, dependent: :destroy

  # Validações
  validates :name, presence: true
  validates :email, uniqueness: { scope: :user_id, allow_blank: true }
  validates :phone, format: {
    with: /\A\+\d{10,15}\z/,
    message: "deve estar no formato internacional (exemplo: +5519996664088 para Brasil)",
    allow_blank: true
  }
  validates :custom_hourly_rate, numericality: { greater_than: 0, allow_blank: true }
  validates :package_value, numericality: { greater_than: 0, allow_blank: true }
  validates :package_hours, numericality: { greater_than: 0, allow_blank: true }

  # Callbacks
  before_validation :format_phone, if: :phone_changed?
  before_create :set_activated_at

  # Enums para status e tipo de plano
  enum status: { active: "active", inactive: "inactive", on_hold: "on_hold" }
  enum plan_type: { credit: "credit", subscription: "subscription" }

  # Scopes
  scope :with_remaining_credits, -> { joins(:customer_credits).where("customer_credits.remaining_hours > 0").distinct }
  scope :with_active_subscriptions, -> { joins(:subscriptions).where(subscriptions: { status: "active" }).distinct }
  scope :with_upcoming_appointments, -> { joins(:appointments).where("appointments.scheduled_at > ?", Time.current).distinct }

  # New scopes for historical tracking
  scope :active_during_month, ->(month_date) {
    month_start = month_date.beginning_of_month
    month_end = month_date.end_of_month

    where(
      # Customer was activated before or during the month
      "activated_at <= ?", month_end
    ).where(
      # And either never cancelled, or cancelled after the month ended
      "cancelled_at IS NULL OR cancelled_at > ?", month_end
    )
  }

  scope :with_payment_history, -> {
    joins(:payments).where("payments.status IN (?)", [ "paid", "cancelled" ]).distinct
  }

  # Métodos auxiliares
  def active_credit
    customer_credits.where("remaining_hours > 0").order(purchase_date: :desc).first
  end

  def total_remaining_hours
    customer_credits.sum(:remaining_hours)
  end

  def active_subscription
    subscriptions.where(status: "active").order(start_date: :desc).first
  end

  # Add a method for unsynced appointments
  def unsynced_appointments
    appointments.unsynced_scheduled
  end

  # Get upcoming unsynced appointments
  def upcoming_unsynced_appointments(weeks_ahead = 4)
    unsynced_appointments.where(
      scheduled_at: Time.current..weeks_ahead.weeks.from_now
    )
  end

  # Get sync status summary for this customer
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

  # Get the effective hourly rate for this customer
  def effective_hourly_rate
    return custom_hourly_rate if custom_hourly_rate.present?

    # Calculate based on manual package values
    if package_value.present? && package_hours.present? && package_hours > 0
      return (package_value / package_hours).round(2)
    end

    # Fallback to service package rate or default
    if credit? && active_credit
      service_package = active_credit.service_package
      return (service_package.price / service_package.hours) if service_package
    elsif subscription? && active_subscription
      service_package = active_subscription.service_package
      return (service_package.price / service_package.hours) if service_package
    end

    # Default rate if no custom rate or service package found
    50.0
  end

  # Check if customer has custom pricing
  def has_custom_pricing?
    custom_hourly_rate.present?
  end

  # Get the package total value for display purposes
  def package_total_value
    # Use manual package value if set
    return package_value if package_value.present?

    # Fallback to existing logic
    if subscription?
      active_subscription&.amount || 0
    else
      last_credit = customer_credits.order(created_at: :desc).first
      last_credit&.service_package&.price || 0
    end
  end

  # Historical activity tracking methods
  def was_active_during_month?(month_date)
    month_start = month_date.beginning_of_month
    month_end = month_date.end_of_month

    # Customer was activated before or during the month
    return false if activated_at && activated_at > month_end

    # Customer was not cancelled, or was cancelled after the month ended
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

  # Calculate total earnings from completed appointments
  def total_earnings
    appointments.completed.sum do |appointment|
      appointment.duration * effective_hourly_rate
    end
  end

  # Calculate earnings for a specific month
  def earnings_for_month(month, year)
    appointments.completed
               .where(scheduled_at: Date.new(year, month, 1).beginning_of_month..Date.new(year, month, 1).end_of_month)
               .sum do |appointment|
      appointment.duration * effective_hourly_rate
    end
  end

  # Calculate total payments received
  def total_payments
    payments.sum(:amount)
  end

  # Calculate payments for a specific month
  def payments_for_month(month, year)
    payments.where(payment_date: Date.new(year, month, 1).beginning_of_month..Date.new(year, month, 1).end_of_month)
            .sum(:amount)
  end

  # Métodos de classe para CSV
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
      # Convert headers to expected format
      row_data = {
        name: row[:nome] || row[:name],
        email: row[:email],
        phone: row[:telefone] || row[:phone],
        status: row[:status] || "active",
        plan_type: row[:tipo_plano] || row[:plan_type] || "credit",
        custom_hourly_rate: row[:preco_personalizado] || row[:custom_hourly_rate]
      }

      # Remove empty phone if present
      row_data[:phone] = nil if row_data[:phone].blank?
      # Remove empty custom_hourly_rate if present
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

    # Remove todos os caracteres que não sejam dígitos ou o símbolo +
    self.phone = phone.gsub(/[^\d+]/, "")

    # Se não começar com +, assumir que é número brasileiro e adicionar +55
    unless phone.start_with?("+")
      self.phone = "+55#{phone}"
    end
  end

  def set_activated_at
    self.activated_at ||= Time.current
  end
end
