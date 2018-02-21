# frozen_string_literal: true

module VIC
  class SupportingDocumentationAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = SupportingDocumentationAttachmentUploader

    def get_file
      uploader = VIC::ProcessingUploader.new(
        "supporting_documentation_attachments/#{guid}",
        parsed_file_data['filename']
      )
      uploader.retrieve_from_store!(uploader.filename)
      uploader.file
    end
  end
end
