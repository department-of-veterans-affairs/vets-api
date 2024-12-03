# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

module BenefitsDocuments
  class UploadStatusUpdater
    # Parses the status of a Lighthouse526DocumentUpload submitted to Lighthouse
    # using metadata from the Lighthouse Benefits Documents API '/uploads/status' endpoint.
    # Provides methods to determine if a document has completed all steps or failed,
    # abstracting away the details of the Lighthouse status data structure.
    #
    # Additionally, updates the state of a Lighthouse526DocumentUpload in vets-api to reflect
    # the current status of a document as it transitions from Lighthouse > VBMS > BGS
    #
    # Documentation on the Lighthouse '/uploads/status' endpoint is available here:
    # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

    # LIGHTHOUSE_DOCUMENT_COMPLETE_STATUS = 'SUCCESS'
    # LIGHTHOUSE_DOCUMENT_FAILED_STATUS = 'FAILED'
    PROCESSING_TIMEOUT_WINDOW_IN_HOURS = 24

    # @param lighthouse_document_status [Hash] includes a single document's status progress
    # after it has been submitted to Lighthouse, while Lighthouse attempts to pass it on to
    # VBMS and then BGS. These data come from Lighthouse's '/uploads/status' endpoint.
    #
    # @param lighthouse526_document_upload [Lighthouse526DocumentUpload] the VA.gov record of the document
    # submitted to Lighthouse for tracking.
    #
    # example lighthouse_document_status hash:
    #  {
    #    "requestId": 600000001,
    #    "time": {
    #      "startTime": 1502199000,
    #      "endTime": 1502199000
    #    },
    #    "status": "IN_PROGRESS",
    #    "steps": [
    #      {
    #        "name": "BENEFITS_GATEWAY_SERVICE",
    #        "nextStepName": "BENEFITS_GATEWAY_SERVICE",
    #        "description": "string",
    #        "status": "NOT_STARTED"
    #      }
    #    ],
    #    "error": {
    #      "detail": "string",
    #      "step": "BENEFITS_GATEWAY_SERVICE"
    #    }
    #  }
    #

    def initialize(lighthouse_document_status_response, lighthouse_document_upload)
      @lighthouse_document_status_response = lighthouse_document_status_response
      @lighthouse_document_upload = lighthouse_document_upload
    end

    def update_status
      # Only save an upload's status if it has transitioned since the last Lighthouse poll
      return unless status_changed?

      # Ensure start time and latest status response from API are saved, regardless if document is still in progress
      @lighthouse_document_upload.update!(
        # lighthouse_processing_started_at: start_time,
        upload_status: @lighthouse_document_status_response['status']
      )

      log_status

      add_acknowledgement_date if failed?

      finalize_upload if completed? || failed?

      # @lighthouse_document_upload.update!(status_last_polled_at: DateTime.now.utc)
    end

    def add_acknowledgement_date
      @lighthouse_document_upload.update!(
        acknowledgement_date: (DateTime.current + 30).utc
      )
    end

    def get_failure_step
      return unless failed? && @lighthouse_document_status_response['error']

      @lighthouse_document_status_response['error']['step']
    end

    # Returns true if document is still processing in Lighthouse, and initiated more than a set number of hours ago
    def processing_timeout?
      return false if @lighthouse_document_status_response.dig('time', 'endTime')

      start_time < PROCESSING_TIMEOUT_WINDOW_IN_HOURS.hours.ago.utc
    end

    private

    def status_changed?
      @lighthouse_document_status_response != @lighthouse_document_upload.upload_status
    end

    # Lighthouse returns date times as UNIX timestamps in milliseconds
    def start_time
      unix_start_time = @lighthouse_document_status_response.dig('time', 'startTime')
      Time.at(unix_start_time / 1000).utc.to_datetime
    end

    def end_time
      unix_end_time = @lighthouse_document_status_response.dig('time', 'endTime')
      Time.at(unix_end_time / 1000).utc.to_datetime
    end

    def failed?
      @lighthouse_document_status_response['status'] == BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
    end

    def completed?
      @lighthouse_document_status_response['status'] == BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]
    end

    def log_status
      Rails.logger.info(
        'BenefitsDocuments::UploadStatusUpdater',
        status: @lighthouse_document_status_response['status'],
        status_response: @lighthouse_document_status_response,
        updated_at: DateTime.now.utc
      )
    end

    def finalize_upload
      # @lighthouse_document_upload.update!(lighthouse_processing_ended_at: end_time)

      if completed?
        @lighthouse_document_upload.update(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS['SUCCESS'])
      else
        @lighthouse_document_upload.update!(
          upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS['FAILED'],
          failed_date: DateTime.now.utc
          # error_message: @lighthouse_document_status['error']
        )
      end
    end
  end
end
