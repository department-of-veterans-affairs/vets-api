class ChangeFormAttachmentsTypeNull < ActiveRecord::Migration
  def change
    change_column :form_attachments, :type, :string, null: false
    change_column_default(:form_attachments, :type, nil)
  end
end
