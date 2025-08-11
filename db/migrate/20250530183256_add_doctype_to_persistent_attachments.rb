class AddDoctypeToPersistentAttachments < ActiveRecord::Migration[7.2]
  def change
    add_column :persistent_attachments, :doctype, :integer
  end
end
