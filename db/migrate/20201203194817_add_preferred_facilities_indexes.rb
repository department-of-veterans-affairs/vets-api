class AddPreferredFacilitiesIndexes < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
     add_index :preferred_facilities, [:facility_code, :account_id], unique: true, algorithm: :concurrently
  end
end
