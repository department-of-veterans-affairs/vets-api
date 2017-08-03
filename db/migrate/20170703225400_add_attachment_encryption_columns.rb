class AddAttachmentEncryptionColumns < ActiveRecord::Migration
  def up
    remove_column(:persistent_attachments, :file_data)
    add_column(:persistent_attachments, :encrypted_file_data, :string, null: false)
    add_column(:persistent_attachments, :encrypted_file_data_iv, :string, null: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
