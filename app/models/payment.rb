class Payment < ApplicationRecord
  belongs_to :customer

  validates :payment_type, :amount, :payment_date, :status, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
  validates :transaction_reference, uniqueness: { scope: :customer_id }, allow_blank: true
  validates :installments, numericality: { greater_than: 0 }, allow_nil: true
  validates :fees, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  enum payment_type: { credit: "credit", subscription: "subscription" }
  enum status: { pending: "pending", paid: "paid", cancelled: "cancelled" }

  # Payment method constants for consistency
  PAYMENT_METHODS = [
    [ "\u{1F4B3} Cart\u00E3o de Cr\u00E9dito", "credit_card" ],
    [ "\u{1F4B8} Cart\u00E3o de D\u00E9bito", "debit_card" ],
    [ "\u{1F3E6} Transfer\u00EAncia Banc\u00E1ria", "bank_transfer" ],
    [ "\u{1F4F1} PIX", "pix" ],
    [ "\u{1F4B5} Dinheiro", "cash" ],
    [ "\u{1F4C4} Boleto", "boleto" ],
    [ "\u{1F514} PayPal", "paypal" ],
    [ "\u{1F4CA} Outros", "other" ]
  ].freeze

  # Scopes
  scope :paid_payments, -> { where(status: "paid") }
  scope :pending_payments, -> { where(status: "pending") }
  scope :cancelled_payments, -> { where(status: "cancelled") }
  scope :by_payment_method, ->(method) { where(payment_method: method) }
  scope :recent_first, -> { order(payment_date: :desc, created_at: :desc) }
  scope :this_month, -> { where(payment_date: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Calculate net amount (amount - fees)
  def net_amount
    amount - (fees || 0)
  end

  # Display payment method with icon
  def payment_method_display
    method_hash = PAYMENT_METHODS.find { |display, value| value == payment_method }
    method_hash ? method_hash[0] : payment_method&.humanize
  end

  # Check if payment was processed (has received_at)
  def processed?
    received_at.present?
  end

  # Human readable status with emoji
  def status_display
    case status
    when "paid"
      "\u2705 Pago"
    when "cancelled"
      "\u274C Cancelado"
    when "pending"
      "\u23F3 Pendente"
    else
      status&.humanize
    end
  end

  # Set received_at when marking as paid
  def mark_as_paid!(processed_by: nil)
    update!(
      status: "paid",
      received_at: Time.current,
      processed_by: processed_by
    )
  end

  # Payment history scope for a customer
  scope :payment_history_for, ->(customer) {
    where(customer: customer)
      .recent_first
      .includes(:customer)
  }
end
