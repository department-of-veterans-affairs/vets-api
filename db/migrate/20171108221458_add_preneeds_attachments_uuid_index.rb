class AddPreneedsAttachmentsUuidIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index "preneed_attachments", 'guid', unique: true, algorithm: :concurrently
  end
end
