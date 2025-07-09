class WhatsappController < ApplicationController
  # Skip authentication for API endpoints called by JavaScript
  skip_before_action :authenticate_user!, only: [ :status, :qr_code, :start_service, :stop_service, :restart_service ]
  # Skip CSRF verification for API endpoints
  skip_before_action :verify_authenticity_token, only: [ :status, :qr_code, :start_service, :stop_service, :restart_service ]

  def auth
    # Renderiza a página de autenticação
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
end
