# frozen_string_literal: true

module VIC
  class DeleteOldUploads < DeleteAttachmentJob
    ATTACHMENT_CLASSES = %w[VIC::ProfilePhotoAttachment VIC::SupportingDocumentationAttachment].freeze
    FORM_ID = 'VIC'

    def get_uuids(form_data)
      uuids = []

      attachments = Array.wrap(form_data['photo']) + Array.wrap(form_data['dd214'])
      attachments.each do |attachment|
        uuids << attachment['confirmationCode']
      end

      uuids
    end
  end
end
