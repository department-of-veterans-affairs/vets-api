# frozen_string_literal: true

require 'datadog'
require 'timeout'
require 'lighthouse/benefits_documents/worker_service'

class Lighthouse::DocumentUploadSynchronous
  def self.upload(user_icn, document_hash)
    client = BenefitsDocuments::WorkerService.new
    document, file_body, uploader = nil

    Datadog::Tracing.trace('Config/Initialize Synchronous Upload Document') do
      Sentry.set_tags(source: 'documents-upload')
      document = LighthouseDocument.new document_hash

      raise Common::Exceptions::ValidationErrors, document_data unless document.valid?

      uploader = LighthouseDocumentUploader.new(user_icn, document.uploader_ids)
      uploader.retrieve_from_store!(document.file_name)
    end
    Datadog::Tracing.trace('Synchronous read_for_upload') do
      file_body = uploader.read_for_upload
    end
    Datadog::Tracing.trace('Synchronous Upload Document') do |span|
      span.set_tag('Document File Size', file_body.size)
      client.upload_document(file_body, document)
    end
    Datadog::Tracing.trace('Remove Upload Document') do
      uploader.remove!
    end
  end
end
