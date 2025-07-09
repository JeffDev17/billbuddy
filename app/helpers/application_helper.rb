module ApplicationHelper
  def format_brazilian_datetime(datetime)
    return "" unless datetime

    # Ensure we're working with the correct timezone
    datetime.in_time_zone("America/Sao_Paulo").strftime("%d/%m/%Y %H:%M")
  end

  def format_brazilian_date(date)
    return "" unless date

    date.strftime("%d/%m/%Y")
  end

  def format_brazilian_time(time)
    return "" unless time

    time.in_time_zone("America/Sao_Paulo").strftime("%H:%M")
  end

  # New methods with Portuguese day-of-the-week names
  def format_brazilian_datetime_with_weekday(datetime)
    return "" unless datetime

    # Ensure we're working with the correct timezone
    datetime_local = datetime.in_time_zone("America/Sao_Paulo")
    weekday = portuguese_weekday_name(datetime_local.wday)

    "#{weekday}, #{datetime_local.strftime('%d/%m/%Y %H:%M')}"
  end

  def format_brazilian_date_with_weekday(date)
    return "" unless date

    weekday = portuguese_weekday_name(date.wday)
    "#{weekday}, #{date.strftime('%d/%m/%Y')}"
  end

  def format_brazilian_date_with_weekday_short(date)
    return "" unless date

    weekday = portuguese_weekday_name_short(date.wday)
    "#{weekday}, #{date.strftime('%d/%m/%Y')}"
  end

  private

  def portuguese_weekday_name(wday)
    case wday
    when 0 then "Domingo"
    when 1 then "Segunda-feira"
    when 2 then "Terça-feira"
    when 3 then "Quarta-feira"
    when 4 then "Quinta-feira"
    when 5 then "Sexta-feira"
    when 6 then "Sábado"
    end
  end

  def portuguese_weekday_name_short(wday)
    case wday
    when 0 then "Dom"
    when 1 then "Seg"
    when 2 then "Ter"
    when 3 then "Qua"
    when 4 then "Qui"
    when 5 then "Sex"
    when 6 then "Sáb"
    end
  end
end
