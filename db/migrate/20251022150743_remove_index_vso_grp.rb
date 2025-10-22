class RemoveIndexVSOGrp < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :veteran_representatives,
                 name: :index_vso_grp,
                 algorithm: :concurrently
  end

  def down
    add_index :veteran_representatives,
              %i[first_name last_name representative_id],
              name: :index_vso_grp,
              algorithm: :concurrently
  end
end