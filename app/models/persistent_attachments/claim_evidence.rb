# frozen_string_literal: true

# This class represents the generic and default persistent attachment type
# used by ClaimDocumentsController when a more specific subclass is not selected
# based on form_id. It provides the default override for claim evidence uploads.
#
# See ClaimDocumentsController#klass for how this class is selected.
class PersistentAttachments::ClaimEvidence < PersistentAttachment
  # Leverages the Shrine gem library to provide file attachment functionality for this model.
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  ##
  # The KMS Encryption Context is preserved from the saved claim model namespace we migrated from
  # ***********************************************************************************
  # Note: This CAN NOT be removed as long as there are existing records of this type. *
  # ***********************************************************************************
  #
  self.inheritance_column = :_type_disabled

  def kms_encryption_context
    {
      model_name: 'PersistentAttachments::PensionBurial',
      model_id: id
    }
  end

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
