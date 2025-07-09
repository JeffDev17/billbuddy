class RecurringAppointmentGrouper
  def initialize(appointments)
    @appointments = appointments
  end

  def group_by_pattern
    @appointments.group_by do |appointment|
      # Round time to nearest 15-minute interval to allow for slight variations
      rounded_time = round_time_to_nearest_15_minutes(appointment.scheduled_at)

      [
        appointment.customer_id,
        rounded_time.strftime("%H:%M"), # Same time (rounded)
        appointment.duration
        # Removed wday - we want to group across different days of the week
      ]
    end
  end

  private

  # Round time to nearest 15-minute interval to allow for slight variations
  def round_time_to_nearest_15_minutes(time)
    minutes = time.min
    rounded_minutes = ((minutes / 15.0).round * 15) % 60
    time.change(min: rounded_minutes, sec: 0)
  end

  # Converte o wday do Ruby (0=domingo, 1=segunda) para a convenção do projeto (0=segunda, 1=terça)
  def convert_ruby_wday_to_project_convention(ruby_wday)
    case ruby_wday
    when 0 then 6  # Domingo -> 6
    when 1 then 0  # Segunda -> 0
    when 2 then 1  # Terça -> 1
    when 3 then 2  # Quarta -> 2
    when 4 then 3  # Quinta -> 3
    when 5 then 4  # Sexta -> 4
    when 6 then 5  # Sábado -> 5
    end
  end
end
