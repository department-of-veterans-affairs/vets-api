# frozen_string_literal: true

# DeleteOldUploadsJob
#
# This Sidekiq job deletes expired 10-10CG (Caregiver Assistance) form uploads from storage.
# It helps manage storage usage and ensures that old, unused attachments are removed.
#
# Why:
# - Prevents accumulation of unused or expired uploads, reducing storage costs and clutter.
# - Supports privacy and security by removing attachments that are no longer needed.
#
# How:
# - Identifies uploads older than the configured expiration time (defined by EXPIRATION_TIME).
# - Deletes expired attachments for the Caregiver Assistance form.
# - Can be extended to support additional attachment classes or forms if needed.

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
