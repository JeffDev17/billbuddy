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

    response = make_request(phone, message)
    handle_response(response)
  rescue StandardError => e
    Rails.logger.error("WhatsApp API Error: #{e.message}")
    raise WhatsappError, "Falha ao enviar mensagem WhatsApp: #{e.message}"
  end

  def get_status
    ensure_service_running!
    response = HTTParty.get("#{whatsapp_api_url}/status", timeout: 10)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("WhatsApp Status Error: #{e.message}")
    { status: "error", error: e.message }
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
