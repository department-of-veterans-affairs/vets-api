class AddToVyeUserInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_user_infos, :bdn_clone_id, :integer
    add_column :vye_user_infos, :bdn_clone_line, :integer
    add_column :vye_user_infos, :bdn_clone_active, :boolean
  end
end
