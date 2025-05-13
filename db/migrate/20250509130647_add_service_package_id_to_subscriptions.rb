class AddServicePackageIdToSubscriptions < ActiveRecord::Migration[6.1]
  def change
    add_reference :subscriptions, :service_package, null: false, foreign_key: true
  end
end