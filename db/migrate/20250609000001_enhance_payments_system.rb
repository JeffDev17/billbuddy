class EnhancePaymentsSystem < ActiveRecord::Migration[7.0]
  def change
    # Add payment method and additional tracking fields
    add_column :payments, :payment_method, :string unless column_exists?(:payments, :payment_method)
    add_column :payments, :transaction_reference, :string unless column_exists?(:payments, :transaction_reference)
    add_column :payments, :received_at, :datetime unless column_exists?(:payments, :received_at)
    add_column :payments, :processed_by, :string unless column_exists?(:payments, :processed_by)
    add_column :payments, :bank_name, :string unless column_exists?(:payments, :bank_name)
    add_column :payments, :installments, :integer, default: 1 unless column_exists?(:payments, :installments)
    add_column :payments, :fees, :decimal, precision: 10, scale: 2, default: 0 unless column_exists?(:payments, :fees)

    # Add status column if it doesn't exist
    unless column_exists?(:payments, :status)
      add_column :payments, :status, :string, default: 'pending'
    end

    # Add indexes for better performance
    add_index :payments, :payment_method unless index_exists?(:payments, :payment_method)
    add_index :payments, :status unless index_exists?(:payments, :status)
    add_index :payments, :transaction_reference unless index_exists?(:payments, :transaction_reference)
    add_index :payments, :received_at unless index_exists?(:payments, :received_at)
    add_index :payments, [ :customer_id, :payment_date ] unless index_exists?(:payments, [ :customer_id, :payment_date ])
    add_index :payments, [ :customer_id, :status ] unless index_exists?(:payments, [ :customer_id, :status ])
  end
end
