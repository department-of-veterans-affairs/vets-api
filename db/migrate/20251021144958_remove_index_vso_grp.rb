class RemoveIndexVSOGrp < ActiveRecord::Migration[7.2]
  def change
    remove_index :veteran_representatives, name: :index_vso_grp
  end
end
