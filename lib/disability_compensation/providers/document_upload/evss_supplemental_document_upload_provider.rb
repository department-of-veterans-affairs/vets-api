# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'

class EVSSSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  STATSD_PROVIDER_METRIC = 'evss_supplemental_document_upload_provider'

  # @param form526_submission [Form526Submission]
  # @param va_document_type [String] VA document code; see LighthouseDocument::DOCUMENT_TYPES
  # @param statsd_metric_prefix [String] prefix, e.g. 'worker.evss.submit_form526_bdd_instructions' from including job
  # @param supporting_evidence_attachment [SupportingEvidenceAttachment] (optional) for Veteran-uploaded documents,
  # the document attachment itself.
  def initialize(form526_submission, va_document_type, statsd_metric_prefix, supporting_evidence_attachment = nil)
    @form526_submission = form526_submission
    @va_document_type = va_document_type
    @statsd_metric_prefix = statsd_metric_prefix
    # Unused for EVSS uploads:
    @supporting_evidence_attachment = supporting_evidence_attachment
  end

  # Uploads to EVSS via the EVSS::DocumentsService require both the file body and an instance
  # of EVSSClaimDocument, so we have to generate and validate that first.
  # Note the EVSSClaimDocument class name is a misnomer; it is more accurately described as
  # an assembly of file-related EVSS metadata, not the actual uploaded file itself
  #
  # @param file_name [String] The name of the file we want to appear in EVSS
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
    log_upload_attempt

    client = EVSS::DocumentsService.new(@form526_submission.auth_headers)
    client.upload(file_body, evss_claim_document)

    # EVSS::DocumentsService uploads throw a EVSS::ErrorMiddleware::EVSSError if they fail
    # If no exception is raised, log a success response
    log_upload_success
  rescue EVSS::ErrorMiddleware::EVSSError => e
    # If exception is raised, log and re-raise the error
    log_upload_failure
    raise e
  end

  # To call in the sidekiq_retries_exhausted block of the including job
  # This is meant to log an upload attempt that was retried and eventually given up on,
  # so we can investigate the failure in Datadog
  #
  # @param uploading_job_class [String] the job where we are uploading the EVSSClaimDocument
  # (e.g. UploadBDDInstructions)
  # @param error_class [String] the Error class of the exception that exhausted the upload job
  # @param error_message [String] the message in the exception that exhausted the upload job
  def log_uploading_job_failure(uploading_job_class, error_class, error_message)
    Rails.logger.error(
      "#{uploading_job_class} EVSSSupplementalDocumentUploadProvider Failure",
      {
        **base_logging_info,
        uploading_job_class:,
        error_class:,
        error_message:
      }
    )

    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STASTD_UPLOAD_JOB_FAILED_METRIC}")
  end

  private

  def base_logging_info
    {
      class: 'EVSSSupplementalDocumentUploadProvider',
      submitted_claim_id: @form526_submission.submitted_claim_id,
      submission_id: @form526_submission.id,
      user_uuid: @form526_submission.user_uuid,
      va_document_type_code: @va_document_type,
      primary_form: 'Form526'
    }
  end

  def log_upload_attempt
    Rails.logger.info('EVSSSupplementalDocumentUploadProvider upload attempted', base_logging_info)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_ATTEMPT_METRIC}")
  end

  def log_upload_success
    Rails.logger.info('EVSSSupplementalDocumentUploadProvider upload successful', base_logging_info)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
  end

  def log_upload_failure
    Rails.logger.error('EVSSSupplementalDocumentUploadProvider upload failed', base_logging_info)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_FAILED_METRIC}")
  end
end
