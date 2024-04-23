class RemoveUserInfoIdFromVyeVerifications < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :vye_verifications, :user_info_id, :integer
    end
  end
end
