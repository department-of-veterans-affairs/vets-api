# TODO: delete after running
module DataMigrations
  module PersistentAttachment
    module_function

    def run
      ::PersistentAttachment.where(type: 'PersistentAttachment::PensionBurial').update_all(type: 'PersistentAttachments::PensionBurial')
    end
  end
end
