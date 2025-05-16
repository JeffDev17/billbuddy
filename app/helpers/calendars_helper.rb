module CalendarsHelper
  def format_datetime_for_input(datetime)
    return nil unless datetime
    datetime = datetime.to_datetime if datetime.is_a?(String)
    datetime.strftime('%Y-%m-%dT%H:%M')
  end

  def format_attendees_for_input(attendees)
    return nil if attendees.nil?
    return attendees if attendees.is_a?(String)
    
    if attendees.is_a?(Array)
      if attendees.first.is_a?(Google::Apis::CalendarV3::EventAttendee)
        # Lidar com objetos EventAttendee do Google Calendar
        attendees.map(&:email).join(', ')
      else
        # Lidar com array de hashes
        attendees.map { |attendee| attendee['email'] }.join(', ')
      end
    else
      attendees.to_s
    end
  end
end
