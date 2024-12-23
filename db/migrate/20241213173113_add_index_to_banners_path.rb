class AddIndexToBannersPath < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_index :banners, :path, algorithm: :concurrently
  end
end
