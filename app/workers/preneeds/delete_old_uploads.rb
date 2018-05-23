# frozen_string_literal: true

module Preneeds
  class DeleteOldUploads < DeleteAttachmentJob
    ATTACHMENT_CLASSES = %w[Preneeds::PreneedAttachment]
    FORM_ID = '40-10007'

    def get_uuids(form_data)
      uuids = []

      attachments = form_data['preneedAttachments']
      if attachments.present?
        attachments.each do |attachment|
          uuids << attachment['confirmationCode']
        end
      end

      uuids
    end
  end
end
