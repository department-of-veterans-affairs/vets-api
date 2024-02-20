# frozen_string_literal: true

module Lighthouse
  module BenefitsDocuments
    module Form526
      class UploadStatusUpdater
        # This class parses the response from the Lighthouse Benefits Documents API uploads/status endpoint
        # Documentation on this endpoint is available here:
        # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

        LIGHTHOUSE_COMPLETED_STATUS_STATE = 'SUCCESS'
        LIGHTHOUSE_FAILED_STATUS_STATE = 'FAILED'

        LIGHTHOUSE_COMPLETED_STEP_STATUS_STATE = 'SUCCESS'

        LIGHTHOUSE_VBMS_STEP_NAME = 'CLAIMS_EVIDENCE'
        LIGHTHOUSE_BGS_STEP_NAME = 'BENEFITS_GATEWAY_SERVICE'

        def initialize(document_upload_progress, lighthouse_document_upload)
          @document_upload_progress = document_upload_progress
          @lighthouse_document_upload = lighthouse_document_upload
        end

        def failed?
          @document_upload_progress[:status] == LIGHTHOUSE_FAILED_STATUS_STATE
        end

        def completed?
          @document_upload_progress[:status] == LIGHTHOUSE_COMPLETED_STATUS_STATE
        end

        def progressed?
          return false if failed?

          if @lighthouse_document_upload.pending_vbms_submission?
            return true if vbms_submission_complete?
          elsif @lighthouse_document_upload.pending_bgs_submission?
            return true if bgs_submission_complete?
          end

          # Status is unchanged
          false
        end

        private

        def vbms_submission_complete?
          vbms_step = @document_upload_progress[:steps].find { |step| step[:name] == LIGHTHOUSE_VBMS_STEP_NAME }
          vbms_step[:status] == LIGHTHOUSE_COMPLETED_STEP_STATUS_STATE
        end

        def bgs_submission_complete?
          vbms_step = @document_upload_progress[:steps].find { |step| step[:name] == LIGHTHOUSE_BGS_STEP_NAME }
          vbms_step[:status] == LIGHTHOUSE_COMPLETED_STEP_STATUS_STATE
        end
      end
    end
  end
end
