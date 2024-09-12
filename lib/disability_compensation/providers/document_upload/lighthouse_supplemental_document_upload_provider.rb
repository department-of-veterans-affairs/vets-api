# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'
require 'lighthouse/benefits_documents/form526/upload_supplemental_document_service'

class LighthouseSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  STATSD_PROVIDER_METRIC = 'lighthouse_supplemental_document_upload_provider'

  # @param form526_submission [Form526Submission]
  def initialize(form526_submission, uploading_class, statsd_metric_prefix)
    @form526_submission = form526_submission
    @uploading_class = uploading_class
    @statsd_metric_prefix = statsd_metric_prefix
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
    user = User.find(@form526_submission.user_uuid)

    LighthouseDocument.new(
      claim_id: @form526_submission.submitted_claim_id,
      participant_id: user.participant_id,
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
  # @param file_body [String]
  #
  # return [Faraday::Response] BenefitsDocuments::WorkerService makes http
  # calls with the Faraday gem under the hood
  def submit_upload_document(lighthouse_document, file_body)
    api_response = BenefitsDocuments::Form526::UploadSupplementalDocumentService.call(file_body, lighthouse_document)
    handle_lighthouse_response(api_response)
  end

  # def log_upload_success(uploading_class_prefix)
  #   StatsD.increment("#{uploading_class_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
  # end

  # def log_upload_failure(uploading_class_prefix, error_class, error_message)
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

  def handle_lighthouse_response(api_response)
    response_body = api_response.body['data']

    if response_body['success'] == true && response_body['requestId']
      Lighthouse526DocumentUpload.create!(
        form526_submission_id: @submission_id,
        # document_type: Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE,
        document_type: polling_record_document_type,
        lighthouse_document_request_id: response_body['requestId']
      )

      StatsD.increment("#{@statsd_metric_prefix}.#{STATSD_PROVIDER_METRIC}.#{STATSD_SUCCESS_METRIC}")
    end
  end

  def polling_record_document_type
    case @uploading_class
    when UploadBddInstructions
      Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE
    end
  end

  # Creates a Lighthouse526DocumentUpload record, where we save
  # a unique 'request ID' Lighthouse provides us in the API response after we upload a document.
  # We use this ID in the Form526DocumentUploadPollingJob chron job to check the status of the document
  # after Lighthouse has received it.
  #
  # @param api_response [Faraday::Response] the response from the Lighthouse Benefits Documents API upload endpoint
  def create_lighthouse_polling_record(api_response)
    response_body = api_response.body['data']

    if response_body['success'] == true && response_body['requestId']
      Lighthouse526DocumentUpload.create!(
        form526_submission_id: @submission_id,
        document_type: Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE,
        lighthouse_document_request_id: response_body['requestId']
      )
    end
  end
end
