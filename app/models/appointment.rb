class Appointment < ApplicationRecord
  # Relacionamentos
  belongs_to :customer

  # Validações
  validates :scheduled_at, :duration, :status, presence: true
  validates :duration, numericality: { greater_than: 0 }

  # Enums
  enum status: { scheduled: 'scheduled', completed: 'completed', cancelled: 'cancelled', no_show: 'no_show' }

  # Callbacks
  after_save :update_customer_credits, if: :completed?

  # Métodos
  def completed?
    status == 'completed'
  end

  private

  def update_customer_credits
    # Se o cliente usa créditos, deduzir as horas da sessão
    if customer.credit?
      credit = customer.active_credit
      if credit
        credit.deduct_hours(duration)
      end
    end
  end
end