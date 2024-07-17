# This migration comes from vye (originally 20240715000017)
class IndexCreatedAtInDirectDeposits < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_direct_deposit_changes, :created_at, algorithm: :concurrently, if_not_exists: true
  end
end
