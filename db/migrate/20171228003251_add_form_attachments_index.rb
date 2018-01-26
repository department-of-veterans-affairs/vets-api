class AddFormAttachmentsIndex < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:form_attachments, [:guid, :type], unique: true, algorithm: :concurrently)
  end
end
