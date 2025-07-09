class AddStatusToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :status, :string, default: 'pending', null: false
    add_index :payments, :status

    # Atualizar registros existentes (se houver) para ter status 'paid'
    reversible do |dir|
      dir.up do
        Payment.update_all(status: 'paid')
      end
    end
  end
end
