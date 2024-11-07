# frozen_string_literal: true

require 'ddtrace'
require 'timeout'
require 'logging/third_party_transaction'
require 'evss/failure_notification'

class EVSS::DocumentUpload
  include Sidekiq::Job
  extend Logging::ThirdPartyTransaction::MethodWrapper

  FILENAME_EXTENSION_MATCHER = /\.\w*$/
  OBFUSCATED_CHARACTER_MATCHER = /[a-zA-Z\d]/

  DD_ZSF_TAGS = ['service:claim-status', 'function: evidence upload to EVSS'].freeze

  NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
  MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.evidence_submission_failure_email

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

  sidekiq_retries_exhausted do |msg, _ex|
    # There should be 3 values in msg['args']:
    # 1) Auth headers needed to authenticate with EVSS
    # 2) The uuid of the record in the UserAccount table
    # 3) Document metadata

    next unless Flipper.enabled?('cst_send_evidence_failure_emails')

    icn = UserAccount.find(msg['args'][1]).icn
    first_name = msg['args'].first['va_eauth_firstName'].titleize
    filename = obscured_filename(msg['args'][2]['file_name'])
    date_submitted = format_issue_instant_for_mailers(msg['created_at'])
    date_failed = format_issue_instant_for_mailers(msg['failed_at'])

    EVSS::FailureNotification.perform_async(icn, first_name, filename, date_submitted, date_failed)

    ::Rails.logger.info('EVSS::DocumentUpload exhaustion handler email queued')
    StatsD.increment('silent_failure_avoided_no_confirmation', tags: DD_ZSF_TAGS)
  rescue => e
    ::Rails.logger.error('EVSS::DocumentUpload exhaustion handler email error',
                         { message: e.message })
    StatsD.increment('silent_failure', tags: DD_ZSF_TAGS)
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
