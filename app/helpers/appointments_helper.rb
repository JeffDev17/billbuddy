module AppointmentsHelper
  # Helper methods for pattern extraction
  def extract_time_from_pattern(pattern)
    # Handle structured hash (new format) or string (old format)
    if pattern.is_a?(Hash)
      return pattern[:time] if pattern[:time].present?
      if pattern[:hour] && pattern[:minute]
        return sprintf("%02d:%02d", pattern[:hour], pattern[:minute])
      end
      return "09:00"
    end

    # Extract time from pattern string like "Segundas às 09:00 (1h)"
    time_match = pattern.to_s.match(/(\d{1,2}):(\d{2})/)
    return "09:00" unless time_match
    "#{time_match[1].rjust(2, '0')}:#{time_match[2]}"
  end

  def extract_duration_from_pattern(pattern)
    # Handle structured hash (new format) or string (old format)
    if pattern.is_a?(Hash)
      return pattern[:duration].to_f if pattern.key?(:duration)
      return 1.0
    end

    # Extract duration from pattern string like "Segundas às 09:00 (1h)"
    duration_match = pattern.to_s.match(/\(([0-9.]+)h\)/)
    return 1.0 unless duration_match
    duration_match[1].to_f
  end

  def extract_confidence_from_pattern(pattern)
    # Handle structured hash (new format) or string (old format)
    if pattern.is_a?(Hash)
      return pattern[:confidence].to_i if pattern.key?(:confidence)
      return 100
    end

    # Extract confidence from pattern string like "Segundas às 09:00 (1h) - 85% confiança"
    confidence_match = pattern.to_s.match(/(\d+)% confiança/)
    return 100 unless confidence_match
    confidence_match[1].to_i
  end

  def pattern_matches_day?(pattern, day_index)
    # Handle structured hash (new format)
    if pattern.is_a?(Hash)
      return pattern[:wday] == day_index if pattern.key?(:wday)
      return false
    end

    # Handle string format (old format)
    day_names = [ "Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "S\u00E1b" ]
    day_name = day_names[day_index]
    pattern.to_s.include?(day_name)
  end
end
