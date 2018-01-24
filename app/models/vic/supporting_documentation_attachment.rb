# frozen_string_literal: true
module VIC
  class SupportingDocumentationAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = SupportingDocumentationAttachmentUploader

    def self.combine_documents(guids)
      guids.each do |guid|
        attachment = where(guid: guid).take
      end
    end
  end
end
