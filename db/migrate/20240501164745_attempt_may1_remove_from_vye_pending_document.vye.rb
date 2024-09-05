# This migration comes from vye (originally 20240501000106)
class AttemptMay1RemoveFromVyePendingDocument < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :vye_pending_documents, :encrypted_kms_key, :text if column_exists?(:vye_pending_documents, :encrypted_kms_key)
    end
  end
end
