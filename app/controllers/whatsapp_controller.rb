class WhatsappController < ApplicationController
  # Skip authentication for API endpoints called by JavaScript
  skip_before_action :authenticate_user!, only: [ :status, :qr_code, :start_service, :stop_service, :restart_service ]
  # Skip CSRF verification for API endpoints
  skip_before_action :verify_authenticity_token, only: [ :status, :qr_code, :start_service, :stop_service, :restart_service ]

  def auth
    @upcoming_reminders = fetch_upcoming_reminders
    @reminder_stats = fetch_reminder_stats
  end

  def status
    status_data = WhatsappApiService.status
    render json: status_data
  rescue => e
    render json: { error: "Erro ao verificar status do WhatsApp", details: e.message }, status: :service_unavailable
  end

  def qr_code
    qr_data = WhatsappApiService.qr_code
    render json: qr_data
  rescue => e
    render json: { error: "Erro ao obter QR code", details: e.message }, status: :service_unavailable
  end

  def start_service
    if WhatsappProcessManager.start!
      render json: { success: true, message: "Servi\u00E7o WhatsApp iniciado com sucesso" }
    else
      render json: { error: "Falha ao iniciar servi\u00E7o WhatsApp" }, status: :service_unavailable
    end
  end

  def stop_service
    WhatsappProcessManager.stop!
    render json: { success: true, message: "Servi\u00E7o WhatsApp parado" }
  end

  def restart_service
    if WhatsappProcessManager.restart!
      render json: { success: true, message: "Servi\u00E7o WhatsApp reiniciado com sucesso" }
    else
      render json: { error: "Falha ao reiniciar servi\u00E7o WhatsApp" }, status: :service_unavailable
    end
  end

  def toggle_reminders
    current_user.update!(appointment_reminders_enabled: !current_user.appointment_reminders_enabled)
    render json: {
      success: true,
      enabled: current_user.appointment_reminders_enabled,
      message: reminders_toggle_message
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reminder_stats
    render json: {
      upcoming: fetch_upcoming_reminders_data,
      stats: fetch_reminder_stats,
      enabled: current_user.appointment_reminders_enabled
    }
  end

  def send_reminder_for_appointment
    appointment = Appointment.joins(customer: :user)
      .where(users: { id: current_user.id })
      .where(status: "scheduled")
      .find(params[:appointment_id])

    service = AppointmentReminderService.new(current_user)
    service.send_reminder_for(appointment, force: true)

    render json: {
      success: true,
      message: "Lembrete enviado para #{appointment.customer.name}!"
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Compromisso não encontrado ou não está agendado" }, status: :not_found
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_upcoming_reminders
    time_range = Time.current.beginning_of_day..Time.current.end_of_day
    Appointment.joins(customer: :user)
      .where(users: { id: current_user.id })
      .needs_reminder_soon(time_range)
      .includes(:customer)
      .order(:scheduled_at)
      .limit(10)
  end

  def fetch_upcoming_reminders_data
    fetch_upcoming_reminders.map do |apt|
      {
        id: apt.id,
        customer_name: apt.customer.name,
        scheduled_at: apt.scheduled_at.strftime("%H:%M"),
        minutes_until: ((apt.scheduled_at - Time.current) / 60).round,
        reminded: apt.reminder_sent_at.present?
      }
    end
  end

  def fetch_reminder_stats
    today = Time.current.beginning_of_day..Time.current.end_of_day
    user_appointments = Appointment.joins(customer: :user).where(users: { id: current_user.id })

    {
      total_today: user_appointments.where(scheduled_at: today, status: "scheduled").count,
      sent_today: user_appointments.where(scheduled_at: today).where.not(reminder_sent_at: nil).count,
      pending_today: user_appointments.needs_reminder_soon(today).count,
      failed_today: FailedNotification.joins(customer: :user)
        .where(users: { id: current_user.id })
        .where(
          notification_type: "appointment_reminder",
          created_at: today
        ).count
    }
  end

  def reminders_toggle_message
    if current_user.appointment_reminders_enabled
      "Lembretes de compromissos ativados"
    else
      "Lembretes de compromissos desativados"
    end
  end
end
