require "net/http"
require "timeout"

class WhatsappApiService
  class WhatsappError < StandardError; end

  def self.send_message(phone, message)
    new.send_message(phone, message)
  end

  def self.ensure_service_running!
    unless WhatsappProcessManager.running?
      Rails.logger.info "WhatsApp service not running, starting..."
      unless WhatsappProcessManager.start!
        raise WhatsappError, "Falha ao iniciar o serviço WhatsApp"
      end
      # Give the service a moment to fully initialize after confirming it's running
      sleep(2)
    end
  end

  def self.status
    new.get_status
  end

  def self.qr_code
    new.get_qr_code
  end

  def send_message(phone, message)
    ensure_service_running!
    validate_phone!(phone)
    validate_message!(message)

    # Try sending with retry logic for "CHAT_NOT_READY" errors
    attempts = 0
    max_attempts = 3

    while attempts < max_attempts
      attempts += 1

      begin
        response = make_request(phone, message)
        handle_response(response)
        return true # Success!

      rescue StandardError => e
        # Retry on both CHAT_NOT_READY and SERVICE_NOT_READY errors
        if (e.message.include?("CHAT_NOT_READY") || e.message.include?("SERVICE_NOT_READY")) && attempts < max_attempts
          Rails.logger.warn("WhatsApp service/chat not ready, retrying... (#{attempts}/#{max_attempts})")
          sleep(5) # Wait 5 seconds before retry
          next
        else
          # Re-raise if it's not a retryable error or we've exhausted retries
          raise e
        end
      end
    end

  rescue StandardError => e
    Rails.logger.error("WhatsApp API Error: #{e.message}")
    raise WhatsappError, "Falha ao enviar mensagem WhatsApp: #{e.message}"
  end

  def get_status
    # Try to get the actual status from the Node.js service
    begin
      response = HTTParty.get("#{whatsapp_api_url}/status", timeout: 10)
      JSON.parse(response.body)
    rescue Errno::ECONNREFUSED, Timeout::Error => e
      # Service is not responding - it's actually stopped
      { status: "stopped", authenticated: false }
    rescue => e
      Rails.logger.error("WhatsApp Status Error: #{e.message}")
      { status: "error", authenticated: false, error: e.message }
    end
  end

  def get_qr_code
    ensure_service_running!
    response = HTTParty.get("#{whatsapp_api_url}/qr-code", timeout: 10)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("WhatsApp QR Code Error: #{e.message}")
    { status: "error", error: e.message }
  end

  private

  def ensure_service_running!
    self.class.ensure_service_running!
  end

  def validate_phone!(phone)
    # Validação básica do telefone
    raise WhatsappError, "Número de telefone inválido" unless phone.match?(/^\+\d{10,15}$/)
  end

  def validate_message!(message)
    # Validação básica da mensagem
    raise WhatsappError, "Mensagem muito longa" if message.length > 4096
    raise WhatsappError, "Mensagem não pode estar vazia" if message.strip.empty?
  end

  def make_request(phone, message)
    HTTParty.post(
      "#{whatsapp_api_url}/send-message",
      headers: request_headers,
      body: request_body(phone, message),
      timeout: 30
    )
  end

  def request_headers
    {
      "Content-Type" => "application/json"
    }
  end

  def request_body(phone, message)
    {
      phone: phone,
      message: message
    }.to_json
  end

  def handle_response(response)
    case response.code
    when 200
      true
    when 400
      raise WhatsappError, "Requisição inválida: #{response.body}"
    when 500
      raise WhatsappError, "Erro no servidor WhatsApp: #{response.body}"
    else
      raise WhatsappError, "Erro inesperado: #{response.body}"
    end
  end

  def whatsapp_api_url
    WhatsappProcessManager.api_url
  end
end
