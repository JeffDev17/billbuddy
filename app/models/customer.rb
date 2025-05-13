class Customer < ApplicationRecord
  include CreditDeductible
  
  # Relacionamentos
  belongs_to :user
  has_many :customer_credits, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :extra_time_balances, dependent: :destroy
  has_many :payments, dependent: :destroy

  # Validações
  validates :name, :email, presence: true
  validates :email, uniqueness: { scope: :user_id }
  validates :phone, format: { 
    with: /\A\+\d{10,15}\z/, 
    message: "deve estar no formato internacional (exemplo: +5519996664088 para Brasil)", 
    allow_blank: true 
  }

  # Callbacks
  before_validation :format_phone, if: :phone_changed?

  # Enums para status e tipo de plano
  enum status: { active: 'active', inactive: 'inactive', on_hold: 'on_hold' }
  enum plan_type: { credit: 'credit', subscription: 'subscription' }

  # Scopes
  scope :with_remaining_credits, -> { joins(:customer_credits).where('customer_credits.remaining_hours > 0').distinct }
  scope :with_active_subscriptions, -> { joins(:subscriptions).where(subscriptions: { status: 'active' }).distinct }
  scope :with_upcoming_appointments, -> { joins(:appointments).where('appointments.scheduled_at > ?', Time.current).distinct }

  # Métodos auxiliares
  def active_credit
    customer_credits.where('remaining_hours > 0').order(purchase_date: :desc).first
  end

  def total_remaining_hours
    customer_credits.sum(:remaining_hours)
  end

  def active_subscription
    subscriptions.where(status: 'active').order(start_date: :desc).first
  end

  private

  def format_phone
    return if phone.blank?
    # Remove caracteres não numéricos, mantendo o +
    self.phone = phone.gsub(/[^\d+]/, '')
    # Garante que começa com +
    self.phone = "+#{phone}" unless phone.start_with?('+')
  end
end