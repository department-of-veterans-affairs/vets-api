class AddTudAccountsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :tud_accounts do |t|
      t.string :tud_id
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.integer :loa_level
      t.belongs_to(:account, foreign_key: true)
    end
    add_index(:tud_accounts, :tud_id)
  end
end
