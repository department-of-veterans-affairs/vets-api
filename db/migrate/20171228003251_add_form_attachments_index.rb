class AddFormAttachmentsIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:form_attachments, [:guid, :type], unique: true, algorithm: :concurrently)
  end
end
