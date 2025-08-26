# frozen_string_literal: true

# This class represents the generic and default persistent attachment type
# used by ClaimDocumentsController when a more specific subclass is not selected
# based on form_id. It provides the default override for claim evidence uploads.
#
# See ClaimDocumentsController#klass for how this class is selected.
class PersistentAttachments::ClaimEvidence < PersistentAttachment
  # Leverages the Shrine gem library to provide file attachment functionality for this model.
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  # @see PersistentAttachment#requires_stamped_pdf_validation
  def requires_stamped_pdf_validation?
    true
  end

  private

  # Deletes the associated file from storage.
  #
  # @return [void]
  def delete_file
    file.delete
  end
end
