# frozen_string_literal: true

module Form1010cg
  class DeleteOldUploadsJob < DeleteAttachmentJob
    ATTACHMENT_CLASSES  = [Form1010cg::Attachment.name].freeze
    FORM_ID             = SavedClaim::CaregiversAssistanceClaim::FORM
    EXPIRATION_TIME     = 30.days

    def uuids_to_keep
      []
    end
  end
end
