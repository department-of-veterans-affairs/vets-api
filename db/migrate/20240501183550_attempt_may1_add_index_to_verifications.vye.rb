# This migration comes from vye (originally 20240501000107)
class AttemptMay1AddIndexToVerifications < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_verifications, :user_profile_id, algorithm: :concurrently
  end
end
