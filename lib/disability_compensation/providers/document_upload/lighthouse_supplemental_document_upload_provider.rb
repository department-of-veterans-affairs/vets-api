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
    api_response = BenefitsDocuments::Form526::UploadSupplementalDocumentService.call(file_body, lighthouse_document)
    handle_lighthouse_response(api_response)
  end

  def log_upload_failure(error_class, error_message)
    StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_FAILED_METRIC}")

    Rails.logger.error(
      'LighthouseSupplementalDocumentUploadProvider upload failure',
      {
        class: 'LighthouseSupplementalDocumentUploadProvider',
        error_class:,
        error_message:
      }
    )
  end

  private

  # Processes the response from Lighthouse and logs accordingly. If the upload is successful, creates
  # a polling record so we can check on the status of the document after Lighthouse has receieved it
  #
  # @param api_response [Faraday::Response] Lighthouse API response returned from the UploadSupplementalDocumentService
  def handle_lighthouse_response(api_response)
    response_body = api_response.body['data']

    if response_body['success'] == true && response_body['requestId']
      create_lighthouse_polling_record(response_body['requestId'])
      StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
    end
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
