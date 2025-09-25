class AppointmentCancellationService
  def initialize(user)
    @user = user
  end

  def cancel_appointment(appointment, options = {})
    reason = options[:reason] || ""
    force_type = options[:force_type] # Para forçar um tipo específico

    # Determinar tipo de cancelamento
    cancellation_type = force_type || determine_cancellation_type(appointment)

    # Atualizar appointment
    appointment.assign_attributes(
      status: "cancelled",
      cancellation_type: cancellation_type,
      cancellation_reason: reason,
      cancelled_at: Time.current
    )

    if appointment.save
      # Remover do calendário se necessário
      appointment.remove_from_calendar if appointment.synced_to_calendar?

      # Log da ação
      log_cancellation(appointment)

      {
        success: true,
        message: cancellation_message(appointment),
        revenue_generated: appointment.cancellation_generates_revenue?,
        revenue_amount: appointment.cancellation_generates_revenue? ? appointment.revenue_amount : 0,
        can_reschedule: appointment.can_be_rescheduled?
      }
    else
      {
        success: false,
        message: "Erro ao cancelar compromisso: #{appointment.errors.full_messages.join(', ')}"
      }
    end
  end

  def reschedule_appointment(appointment, new_datetime, new_duration = nil)
    unless appointment.can_be_rescheduled?
      return {
        success: false,
        message: "Este compromisso não pode ser reagendado."
      }
    end

    # Limpar dados de cancelamento
    appointment.assign_attributes(
      status: "scheduled",
      cancellation_type: nil,
      cancellation_reason: nil,
      cancelled_at: nil,
      reschedule_deadline: nil,
      scheduled_at: new_datetime,
      duration: new_duration || appointment.duration
    )

    if appointment.save
      # Sincronizar com calendário se necessário
      appointment.sync_to_calendar if @user.google_calendar_authorized?

      log_reschedule(appointment)

      {
        success: true,
        message: "Compromisso reagendado com sucesso para #{new_datetime.strftime('%d/%m/%Y às %H:%M')}."
      }
    else
      {
        success: false,
        message: "Erro ao reagendar compromisso: #{appointment.errors.full_messages.join(', ')}"
      }
    end
  end

  def get_cancellation_options(appointment)
    hours_until_appointment = ((appointment.scheduled_at - Time.current) / 1.hour).round(1)

    options = []

    # Sempre permitir cancelamento padrão
    options << {
      type: "standard",
      label: "Cancelamento Normal",
      description: "Cancelamento sem reagendamento nem cobrança"
    }

    # Sempre permitir reagendamento (administração manual)
    options << {
      type: "pending_reschedule",
      label: "Cancelar com Reagendamento",
      description: "Cliente pode reagendar (administração manual)"
    }

    # Se tem menos de 24h, permitir cobrança
    if hours_until_appointment < 24
      revenue_amount = appointment.duration * appointment.customer.effective_hourly_rate
      options << {
        type: "with_revenue",
        label: "Cancelamento em Cima da Hora",
        description: "Valor será adicionado ao faturamento (R$ #{sprintf('%.2f', revenue_amount)})"
      }
    end

    {
      hours_until: hours_until_appointment,
      suggested_type: determine_cancellation_type(appointment),
      options: options
    }
  end

  private

  def determine_cancellation_type(appointment)
    hours_until_appointment = (appointment.scheduled_at - Time.current) / 1.hour

    case hours_until_appointment
    when 0..24
      "with_revenue" # Menos de 24h = cobra
    when 24..Float::INFINITY
      "pending_reschedule" # Mais de 24h = pode reagendar
    else
      "standard" # Fallback
    end
  end



  def cancellation_message(appointment)
    case appointment.cancellation_type
    when "pending_reschedule"
      "Compromisso cancelado. Cliente pode reagendar (administração manual)."
    when "with_revenue"
      "Compromisso cancelado em cima da hora. Valor de R$ #{sprintf('%.2f', appointment.revenue_amount)} adicionado ao faturamento."
    when "standard"
      "Compromisso cancelado."
    else
      "Compromisso cancelado."
    end
  end

  def log_cancellation(appointment)
    Rails.logger.info "Appointment cancelled: #{appointment.id} - Type: #{appointment.cancellation_type} - Reason: #{appointment.cancellation_reason} - User: #{@user.email}"
  end

  def log_reschedule(appointment)
    Rails.logger.info "Appointment rescheduled: #{appointment.id} - New time: #{appointment.scheduled_at} - User: #{@user.email}"
  end
end
