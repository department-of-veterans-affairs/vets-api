# This migration comes from vye (originally 20240713000013)
class IndexUserProfileInPendingDocuments < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_pending_documents, :user_profile_id, algorithm: :concurrently, if_not_exists: true
  end
end
