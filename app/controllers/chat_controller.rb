class ChatController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def weekly_insight
    ai_service = AiChatService.new(current_user)
    insight = ai_service.generate_weekly_insight

    render json: { success: true, message: insight }
  rescue => e
    render json: { success: false, error: e.message }
  end

  def send_message
    message = params[:message]
    return render json: { success: false, error: "Mensagem vazia" } if message.blank?

    ai_service = AiChatService.new(current_user)
    response = ai_service.ask(message)

    render json: { success: true, message: response }
  rescue => e
    render json: { success: false, error: e.message }
  end
end
