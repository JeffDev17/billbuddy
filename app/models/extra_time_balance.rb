class ExtraTimeBalance < ApplicationRecord
  # Relacionamentos
  belongs_to :customer

  # Validações
  validates :hours, :expiry_date, presence: true
  validates :hours, numericality: { greater_than: 0 }

  # Scopes
  scope :valid, -> { where('expiry_date >= ?', Date.today) }

  # Métodos
  def deduct_hours(hours)
    if self.hours >= hours
      update(hours: self.hours - hours)
      true
    else
      false
    end
  end
end