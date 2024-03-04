# frozen_string_literal: true

require 'lighthouse/benefits_documents/form526/documents_status_polling_service'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

module BenefitsDocuments
  module Form526
    class UpdateDocumentsStatusService
      # Queries the Lighthouse Benefits Document API's uploads/status endpoint
      # to check the progression of LighthouseDocumentUploads we uploaded to Lighthouse.
      #
      # After these documents are submitted to Lighthouse, Lighthouse submits them to VBMS,
      # and then if that is successful, to BGS as well. All of these steps must complete before
      # we consider a document successfully processed. Whenever we submit a document to Lighthouse,
      # they return a 'request_id' corresponding to that document. We save this as lighthouse_document_request_id
      # on a LighthouseDocumentUpload record.
      #
      # Lighthouse has provided us with an endpoint, uploads/status, which takes an array of request ids and
      # returns a detailed JSON representiation of that document's progress in uploading to VBMS and BGS,
      # including failures. This service class uses that data to update the status of a LighthouseDocumentUpload,
      # and log success and failure metrics to StatsD, where we will use them to drive dashboards
      #
      # Documentation for Lighthouse's Benefits Document API:
      # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

      STATSD_BASE_KEY = 'api.form_526.lighthouse_document_upload_processing_status'

      STATSD_DOCUMENT_COMPLETE_KEY = 'complete'
      STATSD_DOCUMENT_VBMS_SUBMISSION_FAILED_KEY = 'vbms_submission_failed'
      STATSD_DOCUMENT_BGS_SUBMISSION_FAILED_KEY = 'bgs_submission_failed'

      STATSD_DOCUMENT_TYPE_KEY_MAP = {
        LighthouseDocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE => 'veteran_upload',
        LighthouseDocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE => 'bdd_instructions',
        LighthouseDocumentUpload::FORM_0781_DOCUMENT_TYPE => 'form_0781',
        LighthouseDocumentUpload::FORM_0781A_DOCUMENT_TYPE => 'form_0781a'
      }

      def self.call(args)
        new(args).call
      end

      # @param lighthouse_document_uploads [LighthouseDocumentUpload] a collection of
      # LighthouseDocumentUpload records we are polling for status updates on Lighthouse's
      # uploads/status endpoint
      def initialize(lighthouse_document_uploads)
        @lighthouse_document_uploads = lighthouse_document_uploads
      end

      def call
        update_documents_status
      end

      private

      def update_documents_status
        request_ids = @lighthouse_document_uploads.pluck(:lighthouse_document_request_id)
        response = BenefitsDocuments::Form526::DocumentsStatusPollingService.call(request_ids)

        JSON.parse(response).dig('data', 'statuses').each do |document_progress|
          update_document_status(document_progress)
        end
      end

      def update_document_status(document_progress)
        document_upload = @lighthouse_document_uploads.find_by(lighthouse_document_request_id: document_progress['requestId'])
        document_status_updater = BenefitsDocuments::Form526::UploadStatusUpdater.new(document_progress, document_upload)

        statsd_document_type_key = STATSD_DOCUMENT_TYPE_KEY_MAP[document_upload.document_type]
        statsd_document_base_key = "#{STATSD_BASE_KEY}.#{statsd_document_type_key}"

        if document_status_updater.completed?
          StatsD.increment("#{statsd_document_base_key}.#{STATSD_DOCUMENT_COMPLETE_KEY}")
        elsif document_status_updater.vbms_upload_failed?
          StatsD.increment("#{statsd_document_base_key}.#{STATSD_DOCUMENT_VBMS_SUBMISSION_FAILED_KEY}")
        elsif document_status_updater.bgs_upload_failed?
          StatsD.increment("#{statsd_document_base_key}.#{STATSD_DOCUMENT_BGS_SUBMISSION_FAILED_KEY}")
        end

        document_status_updater.update_status
      end
    end
  end
end
