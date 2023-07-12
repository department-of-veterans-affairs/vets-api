# frozen_string_literal: true

require 'ddtrace'
require 'timeout'

class Lighthouse::DocumentUpload
  include Sidekiq::Worker

  # retry for one day
  sidekiq_options retry: 14, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  def perform(user_icn, document_hash)
    document, client, uploader, file_body = nil

    Datadog::Tracing.trace('Config/Initialize Upload Document') do
      Raven.tags_context(source: 'documents-upload')
      document = LighthouseDocument.new document_hash

      raise Common::Exceptions::ValidationErrors, document_data unless document.valid?

      client = BenefitsDocuments::WorkerService.new(user_icn)
      uploader = LighthouseDocumentUploader.new(user_uuid, document.uploader_ids)
      uploader.retrieve_from_store!(document.file_name)
    end
    Datadog::Tracing.trace('Sidekiq read_for_upload') do
      file_body = uploader.read_for_upload
    end
    Datadog::Tracing.trace('Sidekiq Upload Document') do |span|
      span.set_tag('Document File Size', file_body.size)
      client.upload_document(file_body, document)
    end
    Datadog::Tracing.trace('Remove Upload Document') do
      uploader.remove!
    end
  end
end
