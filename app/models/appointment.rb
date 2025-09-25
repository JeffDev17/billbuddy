class Appointment < ApplicationRecord
  belongs_to :customer
  enum status: { scheduled: "scheduled", completed: "completed", cancelled: "cancelled", no_show: "no_show" }
  enum cancellation_type: {
    pending_reschedule: "pending_reschedule",
    with_revenue: "with_revenue",
    standard: "standard"
  }
  validates :scheduled_at, :duration, :status, presence: true
  validates :duration, numericality: { greater_than: 0 }
  validates :cancellation_type, presence: true, if: :cancelled?
  validates :cancellation_type, inclusion: { in: cancellation_types.keys }, allow_nil: true
  validates :hourly_rate, numericality: { greater_than: 0 }, allow_nil: true
  validates :rate_source, inclusion: { in: %w[custom monthly_package default] }, allow_nil: true
  scope :scheduled_for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }
  scope :today, -> { where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :synced_to_calendar, -> { where.not(google_event_id: nil) }
  scope :not_synced_to_calendar, -> { where(google_event_id: nil) }
  scope :for_sync, -> { where(status: "scheduled", google_event_id: nil) }
  scope :unsynced_scheduled, -> { where(status: "scheduled", google_event_id: nil) }
  scope :unsynced_all, -> { where(google_event_id: nil) }
  scope :recurring_events, -> { where(is_recurring_event: true) }
  scope :single_events, -> { where(is_recurring_event: false) }
  scope :future, -> { where("scheduled_at >= ?", Time.current) }
  scope :cancelled_with_revenue, -> { where(status: "cancelled", cancellation_type: "with_revenue") }
  scope :cancelled_pending_reschedule, -> { where(status: "cancelled", cancellation_type: "pending_reschedule") }
  scope :can_be_rescheduled, -> { cancelled_pending_reschedule }

  before_create :set_appointment_rate
  after_update :sync_to_calendar_if_needed, if: :should_sync_to_calendar?
  def completed?
    status == "completed"
  end

  def synced_to_calendar?
    google_event_id.present?
  end

  def part_of_recurring_series?
    is_recurring_event?
  end

  def sync_to_calendar
    return false unless customer.user.google_calendar_authorized?

    sync_service = GoogleCalendarSyncService.new(customer.user)
    if synced_to_calendar?
      sync_service.update_appointment_event(self)
    else
      sync_service.sync_appointment(self)
    end
  end

  def remove_from_calendar
    return false unless synced_to_calendar? && customer.user.google_calendar_authorized?

    sync_service = GoogleCalendarSyncService.new(customer.user)

    if part_of_recurring_series?
      # For recurring events, we need to handle deletion differently
      # This will delete the entire series - consider adding option for single instance
      sync_service.delete_recurring_event_series(self)
    else
      sync_service.delete_appointment_event(self)
    end
  end

  def cancelled?
    status == "cancelled"
  end

  def can_be_rescheduled?
    cancelled? && cancellation_type == "pending_reschedule"
  end

  def generates_revenue?
    completed? || (cancelled? && cancellation_type == "with_revenue")
  end

  def cancellation_generates_revenue?
    cancelled? && cancellation_type == "with_revenue"
  end

  def revenue_amount
    return 0 unless generates_revenue?
    rate = effective_appointment_rate
    duration * rate
  end

  def effective_appointment_rate
    return hourly_rate if hourly_rate.present?
    customer.effective_hourly_rate
  end

  def has_stored_rate?
    hourly_rate.present?
  end

  def effective_rate_source
    return rate_source if rate_source.present?
    determine_current_rate_source
  end

  def update_stored_rate!(new_rate, source = "manual_override")
    update!(
      hourly_rate: new_rate,
      rate_source: source
    )
  end

  def detailed_status
    case status
    when "cancelled"
      case cancellation_type
      when "pending_reschedule"
        "Cancelado - Reagendamento Pendente"
      when "with_revenue"
        "Cancelado - Em Cima da Hora"
      when "standard"
        "Cancelado"
      else
        "Cancelado"
      end
    else
      status.humanize
    end
  end

  def cancellation_color_class
    return "" unless cancelled?

    case cancellation_type
    when "pending_reschedule"
      "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200"
    when "with_revenue"
      "bg-red-900 text-red-100 dark:bg-red-950 dark:text-red-200"
    when "standard"
      "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    else
      "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    end
  end

  private

  def set_appointment_rate
    return if hourly_rate.present?

    self.hourly_rate = customer.effective_hourly_rate
    self.rate_source = determine_current_rate_source
  end

  def determine_current_rate_source
    return "custom" if customer.custom_hourly_rate.present?
    return "monthly_package" if customer.monthly_amount.present? && customer.monthly_hours.present?
    "default"
  end

  def update_customer_credits
    return if notes&.start_with?("Débito manual:")

    if customer.credit?
      credit = customer.active_credit
      if credit
        credit.deduct_hours(duration)
      end
    end
  end

  def should_sync_to_calendar?
    scheduled? && (saved_change_to_scheduled_at? || saved_change_to_duration?)
  end

  def sync_to_calendar_if_needed
    sync_to_calendar if customer.user.google_calendar_authorized?
  end
end
