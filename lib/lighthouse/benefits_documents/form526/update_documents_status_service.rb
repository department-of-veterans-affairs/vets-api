# frozen_string_literal: true

require 'lighthouse/benefits_documents/form526/documents_status_polling_service'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

module BenefitsDocuments
  module Form526
    class UpdateDocumentsStatusService
      # Queries the Lighthouse Benefits Document API's uploads/status endpoint
      # to check the progression of Lighthouse526DocumentUploads we uploaded to Lighthouse.
      #
      # After these documents are submitted to Lighthouse, Lighthouse submits them to VBMS,
      # and then if that is successful, to BGS as well. All of these steps must complete before
      # we consider a document successfully processed. Whenever we submit a document to Lighthouse,
      # they return a 'request_id' corresponding to that document. We save this as lighthouse_document_request_id
      # on a Lighthouse526DocumentUpload record.
      #
      # Lighthouse has provided us with an endpoint, uploads/status, which takes an array of request ids and
      # returns a detailed JSON representiation of that document's progress in uploading to VBMS and BGS,
      # including failures. This service class uses that data to update the status of a Lighthouse526DocumentUpload,
      # and log success, failure and timeout metrics to StatsD, where we will use them to drive dashboards
      #
      # Documentation for Lighthouse's Benefits Document API:
      # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

      STATSD_BASE_KEY = 'api.form_526.lighthouse_document_upload_processing_status'

      STATSD_DOCUMENT_COMPLETE_KEY = 'complete'
      STATSD_DOCUMENT_FAILED_KEY = 'failed'

      STATSD_DOCUMENT_TYPE_KEY_MAP = {
        Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE => 'veteran_upload',
        Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE => 'bdd_instructions',
        Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE => 'form_0781',
        Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE => 'form_0781a'
      }.freeze

      def self.call(*args)
        new(*args).call
      end

      # @param lighthouse526_document_uploads [Lighthouse526DocumentUpload] a collection of
      # Lighthouse526DocumentUpload records we are polling for status updates on Lighthouse's
      # uploads/status endpoint
      def initialize(lighthouse526_document_uploads, lighthouse_status_response)
        @lighthouse526_document_uploads = lighthouse526_document_uploads
        @lighthouse_status_response = lighthouse_status_response
      end

      def call
        update_documents_status
      end

      private

      def update_documents_status
        @lighthouse_status_response.dig('data', 'statuses').each do |document_progress|
          update_document_status(document_progress)
        end
      end

      def update_document_status(document_progress)
        document_upload = @lighthouse526_document_uploads.find_by!(
          lighthouse_document_request_id: document_progress['requestId']
        )

        # UploadStatusUpdater encapsulates all parsing of a status response from Lighthouse
        status_updater = BenefitsDocuments::Form526::UploadStatusUpdater.new(document_progress, document_upload)
        status_updater.update_status

        statsd_document_type_key = STATSD_DOCUMENT_TYPE_KEY_MAP[document_upload.document_type]
        statsd_document_base_key = "#{STATSD_BASE_KEY}.#{statsd_document_type_key}"

        if document_upload.completed?
          # ex. 'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.complete'
          StatsD.increment("#{statsd_document_base_key}.#{STATSD_DOCUMENT_COMPLETE_KEY}")
        elsif document_upload.failed?
          # Since Lighthouse's processing steps are subject to change, we need to make these metrics dyanmic.
          # E.g. at the moment this should return either claims_evidence or benefits_gateway_service
          failure_step_key = status_updater.get_failure_step.downcase

          # ex. 'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.failed.claims_evidence'
          StatsD.increment("#{statsd_document_base_key}.#{STATSD_DOCUMENT_FAILED_KEY}.#{failure_step_key}")
        elsif status_updater.processing_timeout?
          # Triggered when a document is still pending over 24 hours after it was started
          # ex. 'api.form_526.lighthouse_document_upload_processing_status.bdd_instructions.processing_timeout'
          StatsD.increment("#{statsd_document_base_key}.processing_timeout")
        end
      end
    end
  end
end
