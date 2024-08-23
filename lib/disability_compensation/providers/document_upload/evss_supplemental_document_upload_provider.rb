# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'

class EVSSSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  STATSD_PROVIDER_METRIC = 'evss_supplemental_document_upload_provider'

  # @param form526_submission [Form526Submission]
  def initialize(form526_submission)
    @form526_submission = form526_submission
  end

  # Uploads to EVSS via the EVSS::DocumentsService require both the file body and an instance
  # of EVSSClaimDocument, so we have to generate and validate that first.
  # Note the EVSSClaimDocument class name is a misnomer; it is more accurately described as
  # an assembly of file-related EVSS metadata, not the actual uploaded file itself
  #
  # @param file_name [String] The name of the file we want to appear in EVSS
  # @param document_type [String] The VA document code, which corresponds to
  # the type of document being uploaded ('Buddy/Lay Statement', 'Disability Benefits Questionnaire (DBQ)' etc.)
  # These types are mapped in EVSSClaimDocument[DOCUMENT_TYPES]
  #
  # @return [EVSSClaimDocument]
  def generate_upload_document(file_name, document_type)
    EVSSClaimDocument.new(
      evss_claim_id: @form526_submission.submitted_claim_id,
      file_name:,
      document_type:
    )
  end

  # Takes the necessary validation steps to ensure the document metadata is sufficient
  # for submission to EVSS
  #
  # @param evss_claim_document [EVSSClaimDocument]
  # @retrun [boolean]
  def validate_upload_document(evss_claim_document)
    evss_claim_document.valid?
  end

  # Initializes and uploads via our EVSS Document Service API wrapper
  #
  # @param evss_claim_document
  # @param file_body [String]
  #
  # @return [Faraday::Response] The EVSS::DocumentsService API calls are implemented with Faraday
  def submit_upload_document(evss_claim_document, file_body)
    client = EVSS::DocumentsService.new(@form526_submission.auth_headers)
    client.upload(file_body, evss_claim_document)
  end

  def log_upload_success(uploading_class_prefix)
    StatsD.increment("#{uploading_class_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
  end

  def log_upload_failure(uploading_class_prefix, error_class, error_message)
    StatsD.increment("#{uploading_class_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_FAILED_METRIC}")

    Rails.logger.error(
      'EVSSSupplementalDocumentUploadProvider upload failure',
      {
        class: 'EVSSSupplementalDocumentUploadProvider',
        error_class:,
        error_message:
      }
    )
  end
end
