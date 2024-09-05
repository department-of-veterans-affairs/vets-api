# This migration comes from vye (originally 20240501000100)
class AttemptMay1RemoveSsnAndIcnFromVyeTables < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      # For vye_user_infos
      remove_column :vye_user_infos, :icn, :string if column_exists?(:vye_user_infos, :icn)
      remove_column :vye_user_infos, :ssn_ciphertext, :text if column_exists?(:vye_user_infos, :ssn_ciphertext)
      remove_column :vye_user_infos, :ssn_digest, :string if column_exists?(:vye_user_infos, :ssn_digest)
      
      # For vye_pending_documents
      remove_column :vye_pending_documents, :claim_no_ciphertext, :string if column_exists?(:vye_pending_documents, :claim_no_ciphertext)
      remove_column :vye_pending_documents, :ssn_ciphertext, :text if column_exists?(:vye_pending_documents, :ssn_ciphertext)
      remove_column :vye_pending_documents, :ssn_digest, :string if column_exists?(:vye_pending_documents, :ssn_digest)
    end
  end
end
