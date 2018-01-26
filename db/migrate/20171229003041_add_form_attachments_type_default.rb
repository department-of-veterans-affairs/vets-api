class AddFormAttachmentsTypeDefault < ActiveRecord::Migration
  def change
    FormAttachment.update_all(type: 'Preneeds::PreneedAttachment')
  end
end
