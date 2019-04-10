class PersistentAttachmentIndexes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:persistent_attachments, :guid, unique: true, algorithm: :concurrently)
    add_index(:persistent_attachments, :saved_claim_id, algorithm: :concurrently)
  end
end
