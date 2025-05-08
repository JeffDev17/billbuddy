class CreateServicePackages < ActiveRecord::Migration[7.2]
  def change
    create_table :service_packages do |t|
      t.string :name
      t.integer :hours
      t.decimal :price
      t.boolean :active

      t.timestamps
    end
  end
end
