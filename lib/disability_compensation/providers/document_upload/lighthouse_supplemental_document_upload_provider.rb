# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'
require 'lighthouse/benefits_documents/form526/upload_supplemental_document_service'

class LighthouseSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  STATSD_PROVIDER_METRIC = 'lighthouse_supplemental_document_upload_provider'

  # Maps VA's internal Document Types to the correct document_type attribute for a Lighthouse526DocumentUpload polling
  # record. We need this to create a valid polling record
  POLLING_DOCUMENT_TYPES = {
    'L023' => Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE
  }.freeze

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

  # Uploads to Lighthouse require both the file body and an instance
  # of LighthouseDocument, so we have to generate and validate that first.
  # Note the LighthouseDocument class name is a misnomer; it is more accurately described as
  # an assembly of file-related Lighthouse metadata, not the actual uploaded file itself
  #
  # @param file_name [String] The name of the file we want to appear in Lighthouse
  #
  # @return [LighthouseDocument]
  def generate_upload_document(file_name)
    user = User.find(@form526_submission.user_uuid)

    LighthouseDocument.new(
      claim_id: @form526_submission.submitted_claim_id,
      participant_id: user.participant_id,
      document_type: @va_document_type,
      file_name:
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
  # @param file_body [String]
  def submit_upload_document(lighthouse_document, file_body)
    log_upload_attempt
    api_response = BenefitsDocuments::Form526::UploadSupplementalDocumentService.call(file_body, lighthouse_document)
    handle_lighthouse_response(api_response)
  end

  # To call in the sidekiq_retries_exhausted block of the including job
  # This is meant to log an upload attempt that was retried and eventually given up on,
  # so we can investigate the failure in Datadog
  #
  # @param uploading_job_class [String] the job where we are uploading the Lighthouse Document
  # (e.g. UploadBDDInstructions)
  # @param error_class [String] the Error class of the exception that exhausted the upload job
  # @param error_message [String] the message in the exception that exhausted the upload job
  def log_uploading_job_failure(uploading_job_class, error_class, error_message)
    Rails.logger.error(
      "#{uploading_job_class} LighthouseSupplementalDocumentUploadProvider Failure",
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
      class: 'LighthouseSupplementalDocumentUploadProvider',
      submission_id: @form526_submission.submitted_claim_id,
      user_uuid: @form526_submission.user_uuid,
      va_document_type_code: @va_document_type,
      primary_form: 'Form526'
    }
  end

  def log_upload_attempt
    Rails.logger.info('LighthouseSupplementalDocumentUploadProvider upload attempted', base_logging_info)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_ATTEMPT_METRIC}")
  end

  def log_upload_success(lighthouse_request_id)
    Rails.logger.info(
      'LighthouseSupplementalDocumentUploadProvider upload successful',
      {
        **base_logging_info,
        lighthouse_request_id:
      }
    )

    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
  end

  # For logging an error response from the Lighthouse Benefits Document API
  #
  # @param lighthouse_error_response [Hash] parsed JSON response from the Lighthouse API
  # this will be an array of errors
  def log_upload_failure(lighthouse_error_response)
    Rails.logger.error(
      'LighthouseSupplementalDocumentUploadProvider upload failed',
      {
        **base_logging_info,
        lighthouse_error_response:
      }
    )

    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_FAILED_METRIC}")
  end

  # Processes the response from Lighthouse and logs accordingly. If the upload is successful, creates
  # a polling record so we can check on the status of the document after Lighthouse has receieved it
  #
  # @param api_response [Faraday::Response] Lighthouse API response returned from the UploadSupplementalDocumentService
  def handle_lighthouse_response(api_response)
    response_body = api_response.body

    if lighthouse_success_response?(response_body)
      lighthouse_request_id = response_body.dig('data', 'requestId')
      create_lighthouse_polling_record(lighthouse_request_id)
      log_upload_success(lighthouse_request_id)
    else
      log_upload_failure(response_body)
    end
  end

  # Parses a response from the Lighthouse Benefits Document API
  # If there is a problem with the upload, Lighthouse provides an array of error hashes
  # (See spec/support/vcr_cassettes/lighthouse/benefits_claims/documents/lighthouse_form_526_document_upload_400.yml
  # for an example).
  #
  # If the upload succeeds, we get success metadata nested under a 'data' key, a success flag and a requestId
  # we can use to poll Lighthouse for the document's status later
  def lighthouse_success_response?(response_body)
    !response_body['errors'] && response_body.dig('data', 'success') && response_body.dig('data', 'requestId')
  end

  # Creates a Lighthouse526DocumentUpload polling record
  #
  # @param lighthouse_request_id [String] unique ID Lighthouse provides us in the API response after we
  # upload a document. We use this ID in the Form526DocumentUploadPollingJob chron job to check the status
  # of the document after Lighthouse has received it.
  def create_lighthouse_polling_record(lighthouse_request_id)
    Lighthouse526DocumentUpload.create!(
      form526_submission: @form526_submission,
      document_type: POLLING_DOCUMENT_TYPES[@va_document_type],
      lighthouse_document_request_id: lighthouse_request_id
    )
  end
end
