# frozen_string_literal: true

require 'ddtrace'
require 'timeout'
require 'logging/third_party_transaction'
require 'lighthouse/benefits_documents/constants'

class EVSS::DocumentUpload
  include Sidekiq::Job
  extend SentryLogging
  extend Logging::ThirdPartyTransaction::MethodWrapper

  FILENAME_EXTENSION_MATCHER = /\.\w*$/
  OBFUSCATED_CHARACTER_MATCHER = /[a-zA-Z\d]/

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
  sidekiq_options retry: 16, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  sidekiq_retries_exhausted do |msg, _ex|
    job_id = msg['jid']
    job_class = 'EVSS::DocumentUpload'
    first_name = msg['args'][0]['va_eauth_firstName'].titleize unless msg['args'][0]['va_eauth_firstName'].nil?
    claim_id = msg['args'][2]['evss_claim_id']
    tracked_item_id = msg['args'][2]['tracked_item_id']
    filename = obscured_filename(msg['args'][2]['file_name'])
    date_submitted = format_issue_instant_for_mailers(msg['created_at'])
    date_failed = format_issue_instant_for_mailers(msg['failed_at'])
    upload_status = BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
    uuid = msg['args'][2]['uuid']
    user_account = UserAccount.find_or_create_by(id: uuid)
    personalisation = { first_name:, filename:, date_submitted:, date_failed: }

    EvidenceSubmission.create(
      job_id:,
      job_class:,
      claim_id:,
      tracked_item_id:,
      upload_status:,
      user_account:,
      template_metadata_ciphertext: { personalisation: }.to_json
    )
  rescue => e
    error_message = "#{job_class} failed to create EvidenceSubmission"
    ::Rails.logger.info(error_message, { messsage: e.message })
    StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
    log_exception_to_sentry(e)
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

  def self.obscured_filename(original_filename)
    extension = original_filename[FILENAME_EXTENSION_MATCHER]
    filename_without_extension = original_filename.gsub(FILENAME_EXTENSION_MATCHER, '')

    if filename_without_extension.length > 5
      # Obfuscate with the letter 'X'; we cannot obfuscate with special characters such as an asterisk,
      # as these filenames appear in VA Notify Mailers and their templating engine uses markdown.
      # Therefore, special characters can be interpreted as markdown and introduce formatting issues in the mailer
      obfuscated_portion = filename_without_extension[3..-3].gsub(OBFUSCATED_CHARACTER_MATCHER, 'X')
      filename_without_extension[0..2] + obfuscated_portion + filename_without_extension[-2..] + extension
    else
      original_filename
    end
  end

  def self.format_issue_instant_for_mailers(issue_instant)
    # We want to return all times in EDT
    timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end

  private

  def validate_document!
    Sentry.set_tags(source: 'claims-status')
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
