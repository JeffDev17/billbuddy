class RecurringPatternDetector
  def initialize(appointments)
    @appointments = appointments.sort_by(&:scheduled_at)
  end

  def detect
    return nil if @appointments.size < 2

    # Group appointments by day of week
    appointments_by_day = @appointments.group_by { |apt| apt.scheduled_at.wday }

    # Check if we have a multi-day weekly pattern
    if multi_day_weekly_pattern?(appointments_by_day)
      days = appointments_by_day.keys.sort.map { |wday| weekday_code(wday) }
      {
        freq: "WEEKLY",
        interval: 1,
        byday: days.join(",")
      }
    elsif single_day_weekly_pattern?(appointments_by_day)
      # Single day weekly pattern (fallback for single day)
      wday = appointments_by_day.keys.first
      {
        freq: "WEEKLY",
        interval: 1,
        byday: weekday_code(wday)
      }
    elsif daily_pattern?(calculate_intervals)
      {
        freq: "DAILY",
        interval: 1
      }
    else
      nil
    end
  end

  private

  def multi_day_weekly_pattern?(appointments_by_day)
    return false if appointments_by_day.keys.size < 2

    # Check if each day has a consistent weekly pattern
    appointments_by_day.all? do |wday, appointments|
      appointments.size >= 2 && weekly_pattern_for_day?(appointments)
    end
  end

  def single_day_weekly_pattern?(appointments_by_day)
    return false if appointments_by_day.keys.size != 1

    wday, appointments = appointments_by_day.first
    appointments.size >= 2 && weekly_pattern_for_day?(appointments)
  end

  def weekly_pattern_for_day?(appointments)
    return false if appointments.size < 2

    sorted_appointments = appointments.sort_by(&:scheduled_at)
    intervals = []

    (1...sorted_appointments.size).each do |i|
      days_diff = (sorted_appointments[i].scheduled_at.to_date - sorted_appointments[i-1].scheduled_at.to_date).to_i
      intervals << days_diff
    end

    # Check if intervals are mostly 7 days (weekly)
    return false if intervals.empty?

    weekly_intervals = intervals.count { |interval| interval == 7 }
    total_intervals = intervals.count

    # At least 70% of intervals should be exactly 7 days
    (weekly_intervals.to_f / total_intervals) >= 0.7
  end

  def calculate_intervals
    intervals = []
    (1...@appointments.size).each do |i|
      days_diff = (@appointments[i].scheduled_at.to_date - @appointments[i-1].scheduled_at.to_date).to_i
      intervals << days_diff
    end
    intervals
  end

  def weekly_pattern?(intervals)
    # Allow for some flexibility - most intervals should be 7 days, but allow a few variations
    return false if intervals.empty?

    weekly_intervals = intervals.count { |interval| interval == 7 }
    total_intervals = intervals.count

    # At least 70% of intervals should be exactly 7 days
    (weekly_intervals.to_f / total_intervals) >= 0.7
  end

  def daily_pattern?(intervals)
    # Allow for some flexibility - most intervals should be 1 day
    return false if intervals.empty?

    daily_intervals = intervals.count { |interval| interval == 1 }
    total_intervals = intervals.count

    # At least 80% of intervals should be exactly 1 day
    (daily_intervals.to_f / total_intervals) >= 0.8
  end

  def weekday_code(wday)
    # Usar a convenção padrão do Ruby: 0=domingo, 1=segunda, etc.
    %w[SU MO TU WE TH FR SA][wday]
  end
end
