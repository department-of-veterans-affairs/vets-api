class ChangeFormAttachmentsTypeNull < ActiveRecord::Migration
  def change
    FormAttachment.update_all(type: 'Preneeds::PreneedAttachment')
    change_column :form_attachments, :type, :string, null: false
  end
end
