class AddPreneedsAttachmentsUuidIndex < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index "preneed_attachments", 'guid', unique: true, algorithm: :concurrently
  end
end
