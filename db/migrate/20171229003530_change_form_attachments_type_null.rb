class ChangeFormAttachmentsTypeNull < ActiveRecord::Migration
  safety_assured

  def change
    FormAttachment.update_all(type: 'Preneeds::PreneedAttachment')
    change_column :form_attachments, :type, :string, null: false
  end
end
