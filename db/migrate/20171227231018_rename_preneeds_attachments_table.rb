class RenamePreneedsAttachmentsTable < ActiveRecord::Migration[4.2]
  def change
    rename_table(:preneed_attachments, :form_attachments)
    add_column(:form_attachments, :type, :string)
    remove_index(:form_attachments, name: 'index_form_attachments_on_guid')
  end
end
