# frozen_string_literal: true

class PersistentAttachments::PensionBurial < PersistentAttachment
  UPLOADER_CLASS = ClaimDocumentation::PensionBurial::File
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  UPLOAD_TO_API_EMAILS = %w[
    lihan@adhocteam.us
  ].freeze

  def can_upload_to_api?
    UPLOAD_TO_API_EMAILS.include?(saved_claim.email)
  end
end
