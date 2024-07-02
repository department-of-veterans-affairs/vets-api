class AttemptMay1AddToVyeUserInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_user_infos, :bdn_clone_id, :integer unless column_exists?(:vye_user_infos, :bdn_clone_id)
    add_column :vye_user_infos, :bdn_clone_line, :integer unless column_exists?(:vye_user_infos, :bdn_clone_line)
    add_column :vye_user_infos, :bdn_clone_active, :boolean unless column_exists?(:vye_user_infos, :bdn_clone_active)
  end
end
