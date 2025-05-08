class Customer < ApplicationRecord
  # Relacionamentos
  belongs_to :user
  has_many :customer_credits, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :extra_time_balances, dependent: :destroy

  # Validações
  validates :name, :email, presence: true
  validates :email, uniqueness: { scope: :user_id }

  # Enums para status e tipo de plano
  enum status: { active: 'active', inactive: 'inactive', on_hold: 'on_hold' }
  enum plan_type: { credit: 'credit', subscription: 'subscription' }

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
end