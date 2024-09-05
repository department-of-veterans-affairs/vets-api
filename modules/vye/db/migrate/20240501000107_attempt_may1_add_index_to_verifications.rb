class AttemptMay1AddIndexToVerifications < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_verifications, :user_profile_id, algorithm: :concurrently
  end
end
