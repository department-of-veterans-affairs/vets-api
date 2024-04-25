class AddToVyeUserInfos < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :vye_user_infos, :bdn_clone_id, :integer
    add_column :vye_user_infos, :bdn_clone_line, :integer
    add_column :vye_user_infos, :bdn_clone_active, :boolean

    add_index :vye_user_infos, :bdn_clone_id, algorithm: :concurrently
    add_index :vye_user_infos, :bdn_clone_line, algorithm: :concurrently
    add_index :vye_user_infos, :bdn_clone_active, algorithm: :concurrently
  end
end
