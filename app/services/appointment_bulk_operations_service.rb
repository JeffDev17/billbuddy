class AppointmentBulkOperationsService
  def initialize(user)
    @user = user
  end

  def bulk_mark_completed(appointment_ids, completion_date)
    return { success: false, message: "Selecione pelo menos um compromisso." } if appointment_ids.empty?

    result = appointment_completion_service.bulk_mark_completed(appointment_ids, completion_date)

    if result[:success]
      message = "#{result[:completed_count]} compromisso(s) marcado(s) como concluído(s)! "
      message += "Ganhos totais: R$ #{sprintf('%.2f', result[:total_earnings])}"
      message += " | Data de conclusão: #{result[:completion_date].strftime('%d/%m/%Y')}"

      if result[:errors].any?
        message += " | Alguns erros: #{result[:errors].first}"
      end

      { success: true, message: message }
    else
      { success: false, message: "Erro ao marcar compromissos como concluídos." }
    end
  end

  def bulk_delete_by_customer(customer_id, params = {})
    customer = find_customer(customer_id)
    appointments = customer.appointments

    # Filter by date range if provided
    if params[:start_date].present? && params[:end_date].present?
      appointments = appointments.where(
        scheduled_at: Date.parse(params[:start_date]).beginning_of_day..
                     Date.parse(params[:end_date]).end_of_day
      )
    end

    # Filter for future events only if requested
    appointments = appointments.future if params[:future_only] == "true"

    deleted_count = appointments.count
    appointments.destroy_all

    message_suffix = params[:future_only] == "true" ? " futuros" : ""
    {
      success: true,
      message: "#{deleted_count} compromisso(s)#{message_suffix} de #{customer.name} foram excluídos com sucesso.",
      count: deleted_count
    }
  rescue ActiveRecord::RecordNotFound
    { success: false, message: "Cliente não encontrado." }
  end

  private

  def appointment_completion_service
    @appointment_completion_service ||= AppointmentCompletionService.new(@user)
  end

  def find_customer(customer_id)
    @user.customers.find(customer_id)
  end
end
