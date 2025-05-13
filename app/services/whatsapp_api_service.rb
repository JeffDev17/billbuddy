class WhatsappApiService
  class WhatsappError < StandardError; end

  def self.send_message(phone, message)
    new.send_message(phone, message)
  end

  def send_message(phone, message)
    validate_phone!(phone)
    validate_message!(message)

    response = make_request(phone, message)
    handle_response(response)
  rescue StandardError => e
    Rails.logger.error("WhatsApp API Error: #{e.message}")
    raise WhatsappError, "Falha ao enviar mensagem WhatsApp: #{e.message}"
  end

  private

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
      'Content-Type' => 'application/json'
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
    ENV.fetch('WHATSAPP_API_URL', 'http://localhost:3001')
  end
end 