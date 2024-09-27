# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'

class EVSSSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  STATSD_PROVIDER_METRIC = 'evss_supplemental_document_upload_provider'

  # @param form526_submission [Form526Submission]
  #
  # @param va_document_type [String] The VA document code, which corresponds to
  # the type of document being uploaded ('Buddy/Lay Statement', 'Disability Benefits Questionnaire (DBQ)' etc.)
  # These types are mapped in LighthouseDocument::DOCUMENT_TYPES
  #
  # @param statsd_metric_prefix [String] the metrics prefix the job calling this provider wants us to use when logging
  # (e.g. 'worker.evss.submit_form526_bdd_instructions' for the UploadBddInstructions job)
  #
  def initialize(form526_submission, va_document_type, statsd_metric_prefix)
    @form526_submission = form526_submission
    @va_document_type = va_document_type
    @statsd_metric_prefix = statsd_metric_prefix
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
  def generate_upload_document(file_name)
    EVSSClaimDocument.new(
      evss_claim_id: @form526_submission.submitted_claim_id,
      document_type: @va_document_type,
      file_name:
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

    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
  end

  def log_upload_failure(error_class, error_message)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_FAILED_METRIC}")

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
