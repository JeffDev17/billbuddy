class CustomerCredit < ApplicationRecord
  # Relacionamentos
  belongs_to :customer
  belongs_to :service_package, optional: true

  # Validações
  validates :remaining_hours, :purchase_date, presence: true
  validates :remaining_hours, numericality: true

  # Custom validation: must have either service_package OR custom_hours
  validate :must_have_package_or_custom_hours

  # Callbacks
  before_validation :set_initial_hours, on: :create

  # Métodos
  def deduct_hours(hours)
    update(remaining_hours: remaining_hours - hours)
    true
  end

  def custom_credit?
    service_package.nil?
  end

  def package_name
    custom_credit? ? "Crédito Personalizado" : service_package.name
  end

  def initial_hours
    custom_credit? ? remaining_hours : service_package.hours
  end

  private

  def set_initial_hours
    # Only set from service package if no custom hours provided and package exists
    if service_package.present? && remaining_hours.blank?
      self.remaining_hours = service_package.hours
    end
  end

  def must_have_package_or_custom_hours
    if service_package.blank? && remaining_hours.blank?
      errors.add(:base, "Deve ter um pacote de serviço OU horas personalizadas")
    end
  end
end
