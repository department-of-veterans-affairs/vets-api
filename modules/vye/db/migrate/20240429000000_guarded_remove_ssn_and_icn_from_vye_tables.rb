class GuardedRemoveSsnAndIcnFromVyeTables < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      # For vye_user_infos
      remove_column :vye_user_infos, :icn if column_exists?(:vye_user_infos, :icn)
      remove_column :vye_user_infos, :ssn_ciphertext if column_exists?(:vye_user_infos, :ssn_ciphertext)
      remove_column :vye_user_infos, :ssn_digest if column_exists?(:vye_user_infos, :ssn_digest)
      
      # For vye_pending_documents
      remove_column :vye_pending_documents, :claim_no_ciphertext if column_exists?(:vye_pending_documents, :claim_no_ciphertext)
      remove_column :vye_pending_documents, :ssn_ciphertext if column_exists?(:vye_pending_documents, :ssn_ciphertext)
      remove_column :vye_pending_documents, :ssn_digest if column_exists?(:vye_pending_documents, :ssn_digest)
    end
  end
end
