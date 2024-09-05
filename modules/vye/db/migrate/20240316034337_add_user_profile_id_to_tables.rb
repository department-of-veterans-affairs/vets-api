class AddUserProfileIdToTables < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_user_infos, :user_profile_id, :integer
    add_column :vye_pending_documents, :user_profile_id, :integer
  end
end
