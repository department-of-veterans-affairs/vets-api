class AddUniqueIndexToBannersEntityId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :banners, :entity_id, algorithm: :concurrently
    add_index :banners, :entity_id, unique: true, algorithm: :concurrently
  end
end
