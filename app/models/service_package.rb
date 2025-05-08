class ServicePackage < ApplicationRecord
  # Relacionamentos
  has_many :customer_credits

  # Validações
  validates :name, :hours, :price, presence: true
  validates :hours, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
end