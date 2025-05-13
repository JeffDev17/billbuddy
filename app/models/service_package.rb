class ServicePackage < ApplicationRecord
  # Relacionamentos
  has_many :customer_credits
  has_many :subscriptions

  # Validações
  validates :name, :hours, :price, presence: true
  validates :hours, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }

  # Não há enums aqui, mas podemos adicionar um para status se necessário
  # enum status: { available: 0, unavailable: 1 }, _prefix: true

  # Scopes
  scope :active, -> { where(active: true) }
end