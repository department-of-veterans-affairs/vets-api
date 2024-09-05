# This migration comes from vye (originally 20240502000011)
class AttemptMay2AddBdnCloneIdIndexToUserInfos < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_user_infos, :bdn_clone_id, algorithm: :concurrently
  end
end
