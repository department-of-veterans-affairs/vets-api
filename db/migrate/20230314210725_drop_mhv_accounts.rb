class DropMHVAccounts < ActiveRecord::Migration[6.1]
  def up
    drop_table :mhv_accounts
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
