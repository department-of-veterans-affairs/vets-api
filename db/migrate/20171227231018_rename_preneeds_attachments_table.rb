class RenamePreneedsAttachmentsTable < ActiveRecord::Migration
  def change
    rename_table(:preneed_attachments, :form_attachments)
    add_column(:form_attachments, :type, :string, null: false, default: 'Preneeds::PreneedAttachment')
    remove_index(:form_attachments, name: 'index_form_attachments_on_guid')
  end
end
