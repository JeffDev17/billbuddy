class Subscription < ApplicationRecord
  # Relacionamentos
  belongs_to :customer

  # Validações
  validates :amount, :start_date, :status, presence: true
  validates :amount, numericality: { greater_than: 0 }

  # Enums
  enum status: { active: 'active', cancelled: 'cancelled', paused: 'paused' }
end