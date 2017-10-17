class PersistentAttachmentsNameChange < ActiveRecord::Migration
  def change
    PersistentAttachment.where(type: 'PersistentAttachment::PensionBurial').update_all(type: 'PersistentAttachments::PensionBurial')
  end
end
