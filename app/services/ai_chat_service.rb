class AiChatService
  def initialize(user)
    @user = user
    configure_ruby_llm
  end

  def ask(message)
    chat = RubyLLM.chat(
      provider: :gemini,
      model: "gemini-2.0-flash"
    )
    response = chat.ask(message)
    extract_text_from_response(response)
  end

  def generate_weekly_insight
    context = build_weekly_context
    prompt = build_insight_prompt(context)
    ask(prompt)
  end

  private

  def configure_ruby_llm
    RubyLLM.configure do |config|
      config.gemini_api_key = ENV["GEMINI_API_KEY"]
    end
  end

  def build_weekly_context
    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week

    appointments = Appointment.joins(:customer)
      .where(customers: { user_id: @user.id })
      .where(scheduled_at: week_start..week_end)

    completed = appointments.completed
    cancelled = appointments.cancelled
    cancelled_with_revenue = appointments.cancelled_with_revenue
    scheduled = appointments.scheduled

    revenue = completed.sum { |a| a.revenue_amount }
    revenue_with_cancellations = revenue + cancelled_with_revenue.sum { |a| a.revenue_amount }

    all_by_day = appointments.group_by { |a| a.scheduled_at.to_date }
    completed_by_day = completed.group_by { |a| a.scheduled_at.to_date }
    cancelled_by_day = cancelled.group_by { |a| a.scheduled_at.to_date }

    days_data = (week_start..week_end).map do |date|
      day_appointments = all_by_day[date] || []
      day_completed = completed_by_day[date] || []
      day_cancelled = cancelled_by_day[date] || []

      {
        date: date,
        day_name: I18n.l(date, format: "%A"),
        total: day_appointments.count,
        completed: day_completed.count,
        cancelled: day_cancelled.count,
        scheduled: day_appointments.count - day_completed.count - day_cancelled.count
      }
    end

    {
      total_appointments: appointments.count,
      completed: completed.count,
      cancelled: cancelled.count,
      scheduled: scheduled.count,
      revenue: revenue,
      revenue_with_cancellations: revenue_with_cancellations,
      days_data: days_data
    }
  end

  def build_insight_prompt(context)
    days_summary = context[:days_data].map do |day|
      "#{day[:day_name]}: #{day[:total]} total (#{day[:completed]} concluídos, #{day[:cancelled]} cancelados, #{day[:scheduled]} agendados)"
    end.join("\n")

    <<~PROMPT
      Baseado nos seguintes dados da semana:

      RESUMO GERAL:
      Total de atendimentos: #{context[:total_appointments]}
      Concluídos: #{context[:completed]}
      Cancelados: #{context[:cancelled]}
      Ainda agendados: #{context[:scheduled]}
      Receita (apenas concluídos): R$ #{context[:revenue].round(2)}
      Receita total (incluindo cancelamentos com cobrança): R$ #{context[:revenue_with_cancellations].round(2)}

      DETALHAMENTO POR DIA:
      #{days_summary}

      Gere um resumo semanal em português seguindo estas regras:
      - Tom positivo e construtivo
      - Máximo 4 frases
      - Mencione os números principais
      - Identifique claramente os dias mais cheios e os dias com mais horários livres
      - Sugira como aproveitar os dias mais livres para planejamento ou descanso
      - Seja específico sobre quais dias tiveram mais ou menos movimento
    PROMPT
  end

  def extract_text_from_response(response)
    return response.strip if response.is_a?(String)
    return response.content.text.strip if response.respond_to?(:content) && response.content.respond_to?(:text)
    return response.content.to_s.strip if response.respond_to?(:content)
    response.to_s.strip
  end
end
