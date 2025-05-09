class Payment < ApplicationRecord
  belongs_to :customer

  validates :payment_type, :amount, :payment_date, presence: true
  validates :amount, numericality: { greater_than: 0 }

  enum payment_type: { credit: 'credit', subscription: 'subscription' }
end