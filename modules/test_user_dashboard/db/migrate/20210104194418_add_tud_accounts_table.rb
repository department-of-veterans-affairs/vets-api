class AddTudAccountsTable < ActiveRecord::Migration[6.0]
  def up
    create_table :tud_accounts do |t|
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.integer :loa_level
    end
    add_foreign_key :accounts, :tud_accounts
  end

  def down
    drop_table :tud_accounts
  end
end
