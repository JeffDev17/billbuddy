class AddCancellationTrackingToCustomers < ActiveRecord::Migration[7.0]
  def change
    # Add cancellation tracking to customers
    add_column :customers, :cancelled_at, :datetime unless column_exists?(:customers, :cancelled_at)
    add_column :customers, :cancellation_reason, :text unless column_exists?(:customers, :cancellation_reason)
    add_column :customers, :cancelled_by, :string unless column_exists?(:customers, :cancelled_by)

    # Add activation tracking for better historical records
    add_column :customers, :activated_at, :datetime unless column_exists?(:customers, :activated_at)

    # Add indexes for performance
    add_index :customers, :cancelled_at unless index_exists?(:customers, :cancelled_at)
    add_index :customers, :activated_at unless index_exists?(:customers, :activated_at)
    add_index :customers, [ :status, :cancelled_at ] unless index_exists?(:customers, [ :status, :cancelled_at ])
    add_index :customers, [ :status, :created_at ] unless index_exists?(:customers, [ :status, :created_at ])

    # Set activated_at for existing customers based on created_at
    reversible do |dir|
      dir.up do
        Customer.where(activated_at: nil).update_all("activated_at = created_at")
      end
    end
  end
end
