# frozen_string_literal: true

require 'ddtrace'
require 'timeout'
require 'logging/third_party_transaction'

class EVSS::DocumentUpload
  include Sidekiq::Worker
  extend Logging::ThirdPartyTransaction::MethodWrapper

  attr_accessor :auth_headers, :user_uuid, :document_hash

  wrap_with_logging(
    :pull_file_from_cloud!,
    :perform_initial_file_read,
    :perform_document_upload_to_evss,
    :clean_up!,
    additional_class_logs: {
      form: '526ez Document Upload to EVSS API',
      upstream: "S3 bucket: #{Settings.evss.s3.bucket}",
      downstream: "EVSS API: #{EVSS::DocumentsService::BASE_URL}"
    }
  )

  # retry for one day
  sidekiq_options retry: 14, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  def perform(auth_headers, user_uuid, document_hash)
    @auth_headers = auth_headers
    @user_uuid = user_uuid
    @document_hash = document_hash

    validate_document!
    pull_file_from_cloud!
    perform_document_upload_to_evss
    clean_up!
  end

  private

  def validate_document!
    Raven.tags_context(source: 'claims-status')
    raise Common::Exceptions::ValidationErrors unless document.valid?
  end

  def pull_file_from_cloud!
    uploader.retrieve_from_store!(document.file_name)
  end

  def perform_document_upload_to_evss
    Rails.logger.info('Begining document upload file to EVSS', filesize: file_body.try(:size))
    client.upload(file_body, document)
  end

  def clean_up!
    uploader.remove!
  end

  def perform_initial_file_read
    uploader.read_for_upload
  end

  def uploader
    @uploader ||= EVSSClaimDocumentUploader.new(user_uuid, document.uploader_ids)
  end

  def document
    @document ||= EVSSClaimDocument.new(document_hash)
  end

  def client
    @client ||= EVSS::DocumentsService.new(auth_headers)
  end

  def file_body
    @file_body ||= perform_initial_file_read
  end
end
