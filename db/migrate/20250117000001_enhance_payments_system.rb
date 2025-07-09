class EnhancePaymentsSystem < ActiveRecord::Migration[7.0]
  def change
    # Add payment method and additional tracking fields
    add_column :payments, :payment_method, :string
    add_column :payments, :transaction_reference, :string
    add_column :payments, :received_at, :datetime
    add_column :payments, :processed_by, :string
    add_column :payments, :bank_name, :string
    add_column :payments, :installments, :integer, default: 1
    add_column :payments, :fees, :decimal, precision: 10, scale: 2, default: 0

    # Add status column if it doesn't exist
    unless column_exists?(:payments, :status)
      add_column :payments, :status, :string, default: 'pending'
    end

    # Add indexes for better performance
    add_index :payments, :payment_method
    add_index :payments, :status
    add_index :payments, :transaction_reference
    add_index :payments, :received_at
    add_index :payments, [ :customer_id, :payment_date ]
    add_index :payments, [ :customer_id, :status ]
  end
end
