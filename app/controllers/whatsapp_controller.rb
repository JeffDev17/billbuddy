class WhatsappController < ApplicationController
  def auth
    # Renderiza a página de autenticação
  end

  def status
    # Faz uma requisição para o serviço do WhatsApp para verificar o status
    response = HTTParty.get("#{ENV['WHATSAPP_API_URL']}/status")
    render json: response.body
  rescue => e
    render json: { error: 'Erro ao verificar status do WhatsApp' }, status: :service_unavailable
  end

  def qr_code
    response = HTTParty.get("#{ENV['WHATSAPP_API_URL']}/qr-code")
    render json: response.body
  rescue => e
    render json: { error: 'Erro ao obter QR code' }, status: :service_unavailable
  end
end 