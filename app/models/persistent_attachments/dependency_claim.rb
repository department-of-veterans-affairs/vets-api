# frozen_string_literal: true

class PersistentAttachments::DependencyClaim < PersistentAttachment
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  # @see PersistentAttachment#requires_stamped_pdf_validation
  def requires_stamped_pdf_validation?
    true
  end

  private

  def delete_file
    file.delete
  end
end
