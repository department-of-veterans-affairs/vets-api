class IndexAccountsOnSecId < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :accounts, :sec_id, algorithm: :concurrently
  end
end
