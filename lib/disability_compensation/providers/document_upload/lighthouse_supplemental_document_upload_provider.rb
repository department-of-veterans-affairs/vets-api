# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'
require 'lighthouse/benefits_documents/form526/upload_supplemental_document_service'

class LighthouseSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  # @param form526_submission [Form526Submission]
  # @param file_body [String]
  def initialize(form526_submission, file_body)
    @form526_submission = form526_submission
    @file_body = file_body
  end

  # Uploads to Lighthouse require both the file body and an instance
  # of LighthouseDocument, so we have to generate and validate that first.
  # Note the LighthouseDocument class name is a misnomer; it is more accurately described as
  # an assembly of file-related Lighthouse metadata, not the actual uploaded file itself
  #
  # @param file_name [String] The name of the file we want to appear in Lighthouse
  # @param document_type [String] The VA document code, which corresponds to
  # the type of document being uploaded ('Buddy/Lay Statement', 'Disability Benefits Questionnaire (DBQ)' etc.)
  # These types are mapped in LighthouseDocument::DOCUMENT_TYPES
  #
  # @return [LighthouseDocument]
  def generate_upload_document(file_name, document_type)
    LighthouseDocument.new(
      evss_claim_id: @form526_submission.submitted_claim_id,
      file_name:,
      document_type:
    )
  end

  # Takes the necessary validation steps to ensure the document metadata is sufficient
  # for submission to Lighthouse
  #
  # @param lighthouse_document [LighthouseDocument]
  # @return [boolean]
  def validate_upload_document(lighthouse_document)
    lighthouse_document.valid?
  end

  # Uploads the supplied file to the Lighthouse Benefits Documents API
  #
  # @param lighthouse_document [LighthouseDocument]
  # return [Faraday::Response] BenefitsDocuments::WorkerService makes http
  # calls with the Faraday gem under the hood
  def submit_upload_document(lighthouse_document)
    BenefitsDocuments::Form526::UploadSupplementalDocumentService.call(@file_body, lighthouse_document)
  end
end
