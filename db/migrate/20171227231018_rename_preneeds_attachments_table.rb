class RenamePreneedsAttachmentsTable < ActiveRecord::Migration
  def change
    rename_table(:preneed_attachments, :form_attachments)
    add_column(:form_attachments, :form_id, :string)
  end
end
