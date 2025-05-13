class Subscription < ApplicationRecord
  # Relacionamentos
  belongs_to :customer
  belongs_to :service_package

  # Validações
  validates :start_date, :billing_day, :status, presence: true
  validates :billing_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 31 }

  # Enums
  enum status: { active: 0, inactive: 1, cancelled: 2 }

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :current, -> { where("end_date IS NULL OR end_date >= ?", Date.today) }
end