class AddUniqueIndexToRepresentativeId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_index :veteran_representatives,
              :representative_id,
              unique: true,
              name: :index_veteran_representatives_on_representative_id,
              algorithm: :concurrently
  end

  def down
    remove_index :veteran_representatives,
                name: :index_veteran_representatives_on_representative_id,
                algorithm: :concurrently
  end
end
