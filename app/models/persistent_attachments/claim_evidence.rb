# frozen_string_literal: true

# This class represents the generic and default persistent attachment type
# used by ClaimDocumentsController when a more specific subclass is not selected
# based on form_id. It provides the default override for claim evidence uploads.
#
# See ClaimDocumentsController#klass for how this class is selected.
#
# Note: The line `include ::ClaimDocumentation::Uploader::Attachment.new(:file)` leverages the Shrine gem library
# to provide file attachment functionality for this model.
class PersistentAttachments::ClaimEvidence < PersistentAttachment
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  # Determines whether stamped PDF validation is required for the attachment.
  #
  # # See ClaimDocumentsController#create for how this method is used.
  #
  # @return [Boolean] always returns true, indicating that stamped PDF validation is required.
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
