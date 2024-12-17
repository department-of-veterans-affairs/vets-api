# frozen_string_literal: true

require 'lighthouse/benefits_documents/form526/documents_status_polling_service'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

module BenefitsDocuments
  module Form526
    class UpdateDocumentsStatusService
      # Queries the Lighthouse Benefits Documents API's '/uploads/status' endpoint
      # to check the progression of Lighthouse526DocumentUpload records submitted to Lighthouse.
      #
      # Once submitted to Lighthouse, they are forwarded to VBMS and, if successful, to BGS as well.
      # All steps must complete before a document is considered to have been successfully processed.
      # Whenever a document is submitted to Lighthouse, a 'request_id' corresponding to that document is returned,
      # which is saved as lighthouse_document_request_id on a Lighthouse526DocumentUpload record.
      #
      # Lighthouse provides an endpoint, '/uploads/status', which takes an array of request ids and ressponds with
      # a detailed JSON representiation of each document's upload progress to VBMS and BGS, including failures.
      # This service class uses those data to update the status of each Lighthouse526DocumentUpload record,
      # and log success, failure and timeout metrics to StatsD, where the data are used to drive dashboards.
      #
      # Documentation for Lighthouse's Benefits Documents API and '/uploads/status' endpoint is available here:
      # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

      STATSD_BASE_KEY = 'api.form526.lighthouse_document_upload_processing_status'
      STATSD_DOCUMENT_COMPLETE_KEY = 'complete'
      STATSD_DOCUMENT_FAILED_KEY = 'failed'
      STATSD_PROCESSING_TIMEOUT_KEY = 'processing_timeout'
      STATSD_DOCUMENT_TYPE_KEY_MAP = {
        Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE => 'veteran_upload',
        Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE => 'bdd_instructions',
        Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE => 'form_0781',
        Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE => 'form_0781a'
      }.freeze

      def self.call(*)
        new(*).call
      end

      # @param lighthouse526_document_uploads [Lighthouse526DocumentUpload] a collection of
      # Lighthouse526DocumentUpload records polled for status updates on Lighthouse's '/uploads/status' endpoint
      # @param lighthouse_status_response [Hash] the parsed JSON response body from the endpoint
      def initialize(lighthouse526_document_uploads, lighthouse_status_response)
        @lighthouse526_document_uploads = lighthouse526_document_uploads
        @lighthouse_status_response = lighthouse_status_response
      end

      def call
        update_documents_status

        unknown_ids = @lighthouse_status_response.dig('data', 'requestIdsNotFound')

        return { success: true } if unknown_ids.blank?

        { success: false, response: { status: 404, body: 'Upload Request Async Status Not Found', unknown_ids: } }
      end

      private

      def update_documents_status
        @lighthouse_status_response.dig('data', 'statuses').each do |status|
          update_document_status(status)
        end
      end

      def update_document_status(status)
        document_upload = @lighthouse526_document_uploads.find_by!(lighthouse_document_request_id: status['requestId'])
        statsd_document_base_key(STATSD_DOCUMENT_TYPE_KEY_MAP[document_upload.document_type])

        status_updater = BenefitsDocuments::Form526::UploadStatusUpdater.new(status, document_upload)
        status_updater.update_status

        if document_upload.completed?
          # ex. 'api.form526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
          StatsD.increment("#{@statsd_document_base_key}.#{STATSD_DOCUMENT_COMPLETE_KEY}")
        elsif document_upload.failed?
          log_failure(status_updater, document_upload)
        elsif status_updater.processing_timeout?
          # Triggered when a document is still pending more than 24 hours after processing began
          # ex. 'api.form526.lighthouse_document_upload_processing_status.bdd_instructions.processing_timeout'
          StatsD.increment("#{@statsd_document_base_key}.#{STATSD_PROCESSING_TIMEOUT_KEY}")
        end
      end

      def statsd_document_base_key(statsd_document_type_key)
        @statsd_document_base_key ||= "#{STATSD_BASE_KEY}.#{statsd_document_type_key}"
      end

      def log_failure(status_updater, document_upload)
        # Because Lighthouse's processing steps are subject to change, these metrics must be dynamic.
        # Currently, this should return either CLAIMS_EVIDENCE or BENEFITS_GATEWAY_SERVICE
        failure_step = status_updater.get_failure_step

        # ex. 'api.form526.lighthouse_document_upload_processing_status.bdd_instructions.failed.claims_evidence'
        StatsD.increment("#{@statsd_document_base_key}.#{STATSD_DOCUMENT_FAILED_KEY}.#{failure_step.downcase}")
        return unless document_upload.form0781_types?

        submission = document_upload.form526_submission
        Rails.logger.warn(
          'Benefits Documents API responded with a failed document upload status', {
            form526_submission_id: submission.id,
            document_type: document_upload.document_type,
            failure_step:,
            lighthouse_document_request_id: document_upload.lighthouse_document_request_id,
            user_uuid: submission.user_uuid
          }
        )
      end
    end
  end
end
