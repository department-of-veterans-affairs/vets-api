# This migration comes from vye (originally 20240502000010)
class AttemptMay2AddBdnCloneActiveIndexToUserInfos < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_user_infos, :bdn_clone_active, algorithm: :concurrently
  end
end
