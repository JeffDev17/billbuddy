class Appointment < ApplicationRecord
  # Relacionamentos
  belongs_to :customer

  # Validações
  validates :scheduled_at, :duration, :status, presence: true
  validates :duration, numericality: { greater_than: 0 }

  # Enums
  enum status: { scheduled: "scheduled", completed: "completed", cancelled: "cancelled", no_show: "no_show" }

  # Scopes
  scope :scheduled_for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }
  scope :today, -> { where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :synced_to_calendar, -> { where.not(google_event_id: nil) }
  scope :not_synced_to_calendar, -> { where(google_event_id: nil) }
  scope :for_sync, -> { where(status: "scheduled", google_event_id: nil) }
  scope :unsynced_scheduled, -> { where(status: "scheduled", google_event_id: nil) }
  scope :unsynced_all, -> { where(google_event_id: nil) } # All appointments not synced (scheduled, completed, etc.)
  scope :recurring_events, -> { where(is_recurring_event: true) }
  scope :single_events, -> { where(is_recurring_event: false) }
  scope :future, -> { where("scheduled_at >= ?", Time.current) }

  after_update :sync_to_calendar_if_needed, if: :should_sync_to_calendar?

  # Métodos
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

  private

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
