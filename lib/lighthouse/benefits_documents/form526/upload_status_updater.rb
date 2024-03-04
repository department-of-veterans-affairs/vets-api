# frozen_string_literal: true

module BenefitsDocuments
  module Form526
    class UploadStatusUpdater
      # Parses the current status of a LighthouseDocumentUpload that has been submitted to Lighthouse,
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

      LIGHTHOUSE_STEP_SUCCEEDED_STATUS = 'SUCCESS'

      LIGHTHOUSE_VBMS_STEP_NAME = 'CLAIMS_EVIDENCE'
      LIGHTHOUSE_BGS_STEP_NAME = 'BENEFITS_GATEWAY_SERVICE'

      # @param lighthouse_document_status [Hash] includes a single document's status progress
      # after it has been submitted to Lighthouse, while Lighthouse attempts to pass it on to
      # VBMS and then BGS. This data comes from Lighthouse's uploads/status endpoint
      #
      # @param lighthouse_document_upload [LighthouseDocumentUpload] the VA.gov record of the document
      # we submitted to Lighthouse we are tracking.
      #
      # example lighthouse_document_status hash:
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
      def initialize(lighthouse_document_status, lighthouse_document_upload)
        @lighthouse_document_status = lighthouse_document_status
        @lighthouse_document_upload = lighthouse_document_upload
      end

      def failed?
        @lighthouse_document_status['status'] == LIGHTHOUSE_DOCUMENT_FAILED_STATUS
      end

      def completed?
        @lighthouse_document_status['status'] == LIGHTHOUSE_DOCUMENT_COMPLETE_STATUS
      end

      def update_status
        if failed?
          handle_upload_failure
          return
        end

        check_vbms_submission_status if @lighthouse_document_upload.pending_vbms_submission?
        check_bgs_submission_status if @lighthouse_document_upload.pending_bgs_submission?
      end

      def vbms_upload_failed?
        @lighthouse_document_status['error']['step'] == LIGHTHOUSE_VBMS_STEP_NAME
      end

      def bgs_upload_failed?
        @lighthouse_document_status['error']['step'] == LIGHTHOUSE_BGS_STEP_NAME
      end

      private
      # MAKE SURE YOU RE RUN THE TESTS FOR THIS

      def handle_upload_failure
        error_message = @lighthouse_document_status['error']
        @lighthouse_document_upload.update!(error_message: error_message.to_json)

        if vbms_upload_failed?
          @lighthouse_document_upload.vbms_submission_failed!(@document_upload_status)
        elsif bgs_upload_failed?
          @lighthouse_document_upload.bgs_submission_failed!(@document_upload_status)
        end
      end

      def check_vbms_submission_status
        vbms_step = @lighthouse_document_status['steps'].find { |step| step['name'] == LIGHTHOUSE_VBMS_STEP_NAME }

        if vbms_step['status'] == LIGHTHOUSE_STEP_SUCCEEDED_STATUS
          @lighthouse_document_upload.vbms_submission_complete!(@document_upload_status)
        end
      end

      def check_bgs_submission_status
        bgs_step = @lighthouse_document_status['steps'].find { |step| step['name'] == LIGHTHOUSE_BGS_STEP_NAME }

        if bgs_step['status'] == LIGHTHOUSE_STEP_SUCCEEDED_STATUS
          processing_end_time = @lighthouse_document_status.dig('time', 'endTime')

          # Document is complete, save end time
          # Lighthouse returns date times as UNIX timestamps
          formatted_end_time = DateTime.strptime(processing_end_time, '%s')
          @lighthouse_document_upload.update!(lighthouse_processing_ended_at: formatted_end_time)
          @lighthouse_document_upload.bgs_submission_complete!(@document_upload_status)
        end
      end
    end
  end
end
