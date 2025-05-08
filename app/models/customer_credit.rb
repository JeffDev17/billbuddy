class CustomerCredit < ApplicationRecord
  # Relacionamentos
  belongs_to :customer
  belongs_to :service_package

  # Validações
  validates :remaining_hours, :purchase_date, presence: true
  validates :remaining_hours, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :set_initial_hours, on: :create

  # Métodos
  def deduct_hours(hours)
    if remaining_hours >= hours
      update(remaining_hours: remaining_hours - hours)
      true
    else
      false
    end
  end

  private

  def set_initial_hours
    self.remaining_hours = self.remaining_hours || service_package.hours
  end
end