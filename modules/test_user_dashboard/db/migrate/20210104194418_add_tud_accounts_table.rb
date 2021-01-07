class AddTudAccountsTable < ActiveRecord::Migration[6.0]
  def up
    create_table :tud_accounts do |t|
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.integer :loa_level, :accounts_id
    end
  end

  def down
    drop_table :tud_accounts
  end
end