class TudAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :tud_accounts do |t|
      t.belongs_to :account
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.timestamps
    end
  end
end
