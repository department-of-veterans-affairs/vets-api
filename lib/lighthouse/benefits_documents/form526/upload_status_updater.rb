# frozen_string_literal: true

module BenefitsDocuments
  module Form526
    class UploadStatusUpdater
      # Parses the current status of a Lighthouse526DocumentUpload that has been submitted to Lighthouse,
      # using metadata returned from the Lighthouse Benefits Documents API '/uploads/status' endpoint
      # Encapsulates convenience methods for understanding if the document has completed all steps in Lighthouse or
      # if there was a failure, to avoid having code elsewhere know the schema of Lighthouse's status data structure
      #
      # Additionally, updates the state of the LighthouseDocumentUpload in vets-api to reflect
      # the current status of the document as it makes its way from Lighthouse > VBMS > BGS
      #
      # Documentation on the Lighthouse '/uploads/status' endpoint is available here:
      # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

      LIGHTHOUSE_DOCUMENT_COMPLETE_STATUS = 'SUCCESS'
      LIGHTHOUSE_DOCUMENT_FAILED_STATUS = 'FAILED'
      PROCESSING_TIMEOUT_WINDOW_IN_HOURS = 24

      # @param lighthouse526_document_status [Hash] includes a single document's status progress
      # after it has been submitted to Lighthouse, while Lighthouse attempts to pass it on to
      # VBMS and then BGS. This data comes from Lighthouse's uploads/status endpoint
      #
      # @param lighthouse526_document_upload [Lighthouse526DocumentUpload] the VA.gov record of the document
      # we submitted to Lighthouse we are tracking.
      #
      # example lighthouse526_document_status hash:
      #     {
      #       {
      #         "requestId": 600000001,
      #         "time": {
      #           "startTime": 1502199000,
      #           "endTime": 1502199000
      #         },
      #         "status": "IN_PROGRESS",
      #         "steps": [
      #           {
      #             "name": "BENEFITS_GATEWAY_SERVICE",
      #             "nextStepName": "BENEFITS_GATEWAY_SERVICE",
      #             "description": "string",
      #             "status": "NOT_STARTED"
      #           }
      #         ],
      #         "error": {
      #           "detail": "string",
      #           "step": "BENEFITS_GATEWAY_SERVICE"
      #         }
      #       }
      #     }
      #

      def initialize(lighthouse526_document_status, lighthouse526_document_upload)
        @lighthouse526_document_status = lighthouse526_document_status
        @lighthouse526_document_upload = lighthouse526_document_upload
      end

      def update_status
        # We only save an upload's status if it has transitioned on the Lighthouse side
        # since the last time we polled
        return unless status_changed?

        # Save these regardless of whether the document is still in progress or not
        # We want to ensure we've saved the start time and the latest status response from the API
        @lighthouse526_document_upload.update!(
          lighthouse_processing_started_at: start_time,
          last_status_response: @lighthouse526_document_status
        )

        # We always log the status check to the Rails logger as well
        Rails.logger.info(
          'BenefitsDocuments::Form526::UploadStatusUpdater',
          status: @lighthouse526_document_status['status'],
          status_response: @lighthouse526_document_status,
          updated_at: DateTime.now
        )

        if completed? || failed?
          @lighthouse526_document_upload.update!(lighthouse_processing_ended_at: end_time)

          if completed?
            @lighthouse526_document_upload.complete!
          else
            @lighthouse526_document_upload.update!(error_message: @lighthouse526_document_status['error'])
            @lighthouse526_document_upload.fail!
          end
        end
      end

      def get_failure_step
        return unless failed? && @lighthouse526_document_status['error']

        @lighthouse526_document_status['error']['step']
      end

      # Returns true if document is still processing in Lighthouse,
      # and it was started over a certain amount of hours ago
      def processing_timeout?
        return false if @lighthouse526_document_status.dig('time', 'endTime')

        start_time < PROCESSING_TIMEOUT_WINDOW_IN_HOURS.hours.ago
      end

      private

      def status_changed?
        @lighthouse526_document_status != @lighthouse526_document_upload.last_status_response
      end

      def start_time
        # Lighthouse returns date times as UNIX timestamps
        unix_start_time = @lighthouse526_document_status.dig('time', 'startTime')
        DateTime.strptime(unix_start_time, '%s')
      end

      def end_time
        # Lighthouse returns date times as UNIX timestamps
        unix_end_time = @lighthouse526_document_status.dig('time', 'endTime')
        DateTime.strptime(unix_end_time, '%s')
      end

      def failed?
        @lighthouse526_document_status['status'] == LIGHTHOUSE_DOCUMENT_FAILED_STATUS
      end

      def completed?
        @lighthouse526_document_status['status'] == LIGHTHOUSE_DOCUMENT_COMPLETE_STATUS
      end
    end
  end
end
