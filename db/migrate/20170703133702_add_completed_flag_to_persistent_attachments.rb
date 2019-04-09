class AddCompletedFlagToPersistentAttachments < ActiveRecord::Migration[4.2]
  def change
    add_column :persistent_attachments, :completed_at, :datetime
  end
end
