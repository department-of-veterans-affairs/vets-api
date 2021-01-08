class AddTudAccountsTable < ActiveRecord::Migration[6.0]
  def up
    create_table :tud_accounts do |t|
      t.belongs_to :account
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.integer :loa_level
    end
  end

  def down
    drop_table :tud_accounts
  end
end
