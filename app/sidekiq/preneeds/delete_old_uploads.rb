# frozen_string_literal: true

module Preneeds
  class DeleteOldUploads < DeleteAttachmentJob
    ATTACHMENT_CLASSES = %w[Preneeds::PreneedAttachment].freeze
    FORM_ID = '40-10007'

    def get_uuids(form_data)
      uuids = []

      Array.wrap(form_data['preneedAttachments']).each do |attachment|
        uuids << attachment['confirmationCode']
      end

      uuids
    end
  end
end
