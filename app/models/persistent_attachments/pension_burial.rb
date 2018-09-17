# frozen_string_literal: true

class PersistentAttachments::PensionBurial < PersistentAttachment
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  UPLOAD_TO_API_EMAILS = %w[
    lihan@adhocteam.us
  ].freeze

  def can_upload_to_api?
    UPLOAD_TO_API_EMAILS.include?(saved_claim.email)
  end

  private

  def delete_file
    file.delete
  end
end
