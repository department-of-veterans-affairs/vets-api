# This migration comes from vye (originally 20240422051918)
class RemoveFromVyePendingDocument < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :vye_pending_documents, :encrypted_kms_key
    end
  end
end
