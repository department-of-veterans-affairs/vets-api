class AddFormAttachmentsTypeDefault < ActiveRecord::Migration
  def change
    change_column_default(:form_attachments, :type, 'Preneeds::PreneedAttachment')
  end
end
