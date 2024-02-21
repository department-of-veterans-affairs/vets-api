# frozen_string_literal: true

module Lighthouse
  module BenefitsDocuments
    module Form526
      class UpdateDocumentsStatusService
        def self.call(args)
          new(args).call
        end

        def initialize(lighthouse_document_uploads)
          @lighthouse_document_uploads = lighthouse_document_uploads
        end

        def call
          update_documents_status
        end

        private

        def update_documents_status
          request_ids = @lighthouse_document_uploads
          response = Services::Form526::LighthouseDocumentStatusPollingService.call(request_ids)

          JSON.parse(response).dig('data', 'statuses') do |document_progress|
            update_document_status(document_progress)
          end
        end

        def update_document_status(document_progress)
          document_upload = @lighthouse_document_uploads.find_by(lighthouse_document_request_id: document_progress['requestId'])
          lighthouse_status_update = LighthouseDocumentUploadStatusUpdater.new(document_progress, document_upload)

          return unless lighthouse_status_update.changed?

          if lighthouse_status_update.finished?
            # success will log here
            lighthouse_status_update.finish_document_upload
          elsif lighthouse_status_update.failed?
            # Errors will log here
            lighthouse_status_update.fail_document_upload
          else
            # Log status update?
            lighthouse_status_update.update_document_upload
          end
        end
      end
    end
  end
end
