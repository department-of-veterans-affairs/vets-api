class AddVyependingdocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :vye_pending_documents, :encrypted_kms_key, :text, if_not_exists: true
  end
end
