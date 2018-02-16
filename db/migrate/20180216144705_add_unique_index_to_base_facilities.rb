class AddUniqueIndexToBaseFacilities < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :base_facilities, :unique_id, unique: true, algorithm: :concurrently
  end
end
