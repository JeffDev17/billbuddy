class CustomerSchedule < ApplicationRecord
  belongs_to :customer

  # Validations
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :for_day, ->(day) { where(day_of_week: day) }

  # Constants for day names
  DAYS_OF_WEEK = {
    0 => "Domingo",
    1 => "Segunda-feira",
    2 => "Ter\u00E7a-feira",
    3 => "Quarta-feira",
    4 => "Quinta-feira",
    5 => "Sexta-feira",
    6 => "S\u00E1bado"
  }.freeze

  # Helper methods
  def day_name
    DAYS_OF_WEEK[day_of_week]
  end

  def formatted_time
    start_time.strftime("%H:%M")
  end

  def formatted_schedule
    "#{day_name} às #{formatted_time} (#{duration}h)"
  end

  # Create appointment datetime for a given date
  def appointment_time_for_date(date)
    return nil unless date.wday == day_of_week

    Time.zone.local(
      date.year,
      date.month,
      date.day,
      start_time.hour,
      start_time.min
    )
  end

  # Check if this schedule applies to a given date
  def applies_to_date?(date)
    enabled? && date.wday == day_of_week
  end
end
