# frozen_string_literal: true

module VIC
  class DeleteOldUploads < DeleteAttachmentJob
    ATTACHMENT_CLASSES = [VIC::ProfilePhotoAttachment, VIC::SupportingDocumentationAttachment]
    FORM_ID = 'VIC'

    def get_uuids(form_data)
      uuids = []

      attachments = Array.wrap(form_data['photo'])
      attachments += form_data['dd214'] || []

      if attachments.present?
        attachments.each do |attachment|
          uuids << attachment['confirmationCode']
        end
      end

      uuids
    end
  end
end
