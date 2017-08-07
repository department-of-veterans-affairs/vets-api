# frozen_string_literal: true
class PersistentAttachment::PensionBurial < PersistentAttachment
  UPLOADER_CLASS = ClaimDocumentation::PensionBurial::File
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)
end
