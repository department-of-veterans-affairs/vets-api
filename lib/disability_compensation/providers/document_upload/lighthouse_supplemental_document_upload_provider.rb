# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'
require 'lighthouse/benefits_documents/form526/upload_supplemental_document_service'

class LighthouseSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  STATSD_PROVIDER_METRIC = 'lighthouse_supplemental_document_upload_provider'

  # Maps VA's internal Document Types to the correct document_type attribute for a Lighthouse526DocumentUpload polling
  # record. We need this to create a valid polling record
  POLLING_DOCUMENT_TYPES = {
    'L023' => Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE,
    'L228' => Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE,
    'L229' => Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE
  }.freeze
  # @param form526_submission [Form526Submission]
  #
  # @param va_document_type [String] VA document code, see LighthouseDocument::DOCUMENT_TYPES
  # @param statsd_metric_prefix [String] prefix, e.g. 'worker.evss.submit_form526_bdd_instructions' from including job
  # @param supporting_evidence_attachment [SupportingEvidenceAttachment] (optional) for Veteran-uploaded documents,
  # the document attachment itself. Required to create the Lighthouse526DocumentUpload polling record for these uploads
  def initialize(form526_submission, va_document_type, statsd_metric_prefix, supporting_evidence_attachment = nil)
    @form526_submission = form526_submission
    @va_document_type = va_document_type
    @statsd_metric_prefix = statsd_metric_prefix
    @supporting_evidence_attachment = supporting_evidence_attachment
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
    LighthouseDocument.new(
      claim_id: @form526_submission.submitted_claim_id,
      # Participant ID is persisted on the submission record
      participant_id: @form526_submission.auth_headers['va_eauth_pid'],
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

    begin
      api_response = BenefitsDocuments::Form526::UploadSupplementalDocumentService.call(file_body, lighthouse_document)
    rescue => e
      log_upload_failure(e)
      raise e
    end

    handle_lighthouse_response(api_response)
  end

  # To call in the sidekiq_retries_exhausted block of the including job for DataDog monitoring
  #
  # @param uploading_job_class [String] the job uploading the document (e.g. UploadBDDInstructions)
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
      submitted_claim_id: @form526_submission.submitted_claim_id,
      submission_id: @form526_submission.id,
      user_uuid: @form526_submission.user_uuid,
      va_document_type_code: @va_document_type,
      primary_form: 'Form526'
    }
  end

  def log_upload_attempt
    Rails.logger.info('LighthouseSupplementalDocumentUploadProvider upload attempted', base_logging_info)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_ATTEMPT_METRIC}")
  end

  def log_upload_success(lighthouse_document_request_id)
    Rails.logger.info(
      'LighthouseSupplementalDocumentUploadProvider upload successful',
      {
        **base_logging_info,
        lighthouse_document_request_id:
      }
    )

    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
  end

  def log_upload_failure(exception)
    Rails.logger.error(
      'LighthouseSupplementalDocumentUploadProvider upload failed',
      {
        **base_logging_info,
        error_info: exception.errors
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

    lighthouse_document_request_id = response_body['data']['requestId']
    create_lighthouse_polling_record(lighthouse_document_request_id)
    log_upload_success(lighthouse_document_request_id)
  end

  # @param response_body [JSON] Lighthouse API response returned from the UploadSupplementalDocumentService
  def lighthouse_success_response?(response_body)
    !response_body['errors'] && response_body.dig('data', 'success') && response_body.dig('data', 'requestId')
  end

  # Creates a Lighthouse526DocumentUpload polling record
  #
  # @param lighthouse_document_request_id [String] unique ID Lighthouse provides us
  # in the API response for polling later
  def create_lighthouse_polling_record(lighthouse_document_request_id)
    Lighthouse526DocumentUpload.create!(
      form526_submission: @form526_submission,
      document_type: polling_record_document_type,
      lighthouse_document_request_id:,
      # The Lighthouse526DocumentUpload form_attachment association is
      # required for uploads of type Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE
      **form_attachment_params
    )
  end

  def form_attachment_params
    return {} unless @supporting_evidence_attachment

    { form_attachment: @supporting_evidence_attachment }
  end

  # Lighthouse526DocumentUpload polling records are marked and logged according to the type of document uploaded
  # (e.g. "Veteran Upload", "BDD Instructions"). This is separate from the internal VA document code
  # (passed to this service as @va_document_type)
  #
  # @return [string from Lighthouse526DocumentUpload::VALID_DOCUMENT_TYPES]
  def polling_record_document_type
    # Set to Veteran Upload regardless of @va_document_type if @supporting_evidence_attachment is present
    # Veteran-uploaded documents can be numerous VA document types
    return Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE if @supporting_evidence_attachment

    POLLING_DOCUMENT_TYPES[@va_document_type]
  end
end
