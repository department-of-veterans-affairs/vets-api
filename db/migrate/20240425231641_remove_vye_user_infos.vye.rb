class RemoveVyeUserInfos < ActiveRecord::Migration[7.1]
  def change
    remove_index "vye_user_infos", column: [:bdn_clone_id], name: "index_vye_user_infos_on_bdn_clone_id", if_exists: true
    remove_index "vye_user_infos", column: [:bdn_clone_line], name: "index_vye_user_infos_on_bdn_clone_line", if_exists: true
    remove_index "vye_user_infos", column: [:bdn_clone_active], name: "index_vye_user_infos_on_bdn_clone_active", if_exists: true
    safety_assured { remove_column :vye_user_infos, :bdn_clone_id, :integer,  if_exists: true }
    safety_assured { remove_column :vye_user_infos, :bdn_clone_line, :integer, if_exists: true }
    safety_assured { remove_column :vye_user_infos, :bdn_clone_active, :boolean, if_exists: true }
  end
end
