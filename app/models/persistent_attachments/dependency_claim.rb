# frozen_string_literal: true

class PersistentAttachments::DependencyClaim < PersistentAttachment
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  private

  def delete_file
    file.delete
  end
end
