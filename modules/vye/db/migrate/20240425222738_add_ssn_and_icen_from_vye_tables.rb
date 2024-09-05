class AddSsnAndIcenFromVyeTables < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_user_infos, :icn, :string, if_not_exists: true
    add_column :vye_user_infos, :ssn_ciphertext, :text, if_not_exists: true
    add_column :vye_user_infos, :ssn_digest, :string, if_not_exists: true
    add_column :vye_pending_documents, :claim_no_ciphertext, :string, if_not_exists: true
    add_column :vye_pending_documents, :ssn_ciphertext, :text, if_not_exists: true
    add_column :vye_pending_documents, :ssn_digest, :string, if_not_exists: true
  end
end
