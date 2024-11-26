# frozen_string_literal: true

require 'ddtrace'
require 'timeout'
require 'lighthouse/benefits_documents/worker_service'
require 'lighthouse/benefits_documents/constants'

class Lighthouse::DocumentUpload
  include Sidekiq::Job

  attr_accessor :user_icn, :document_hash

  FILENAME_EXTENSION_MATCHER = /\.\w*$/
  OBFUSCATED_CHARACTER_MATCHER = /[a-zA-Z\d]/

  DD_ZSF_TAGS = ['service:claim-status', 'function: evidence upload to Lighthouse'].freeze

  NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
  MAILER_TEMPLATE_ID = NOTIFY_SETTINGS.template_id.evidence_submission_failure_email

  # retry for  2d 1h 47m 12s
  # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
  sidekiq_options retry: 16, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  sidekiq_retries_exhausted do |msg, _ex|
    # There should be 2 values in msg['args']:
    # 1) The ICN of the user
    # 2) Document metadata

    next unless Flipper.enabled?('cst_send_evidence_failure_emails')

    icn = msg['args'].first
    first_name = msg['args'][1]['first_name'].titleize
    filename = obscured_filename(msg['args'][1]['file_name'])
    date_submitted = format_issue_instant_for_mailers(msg['created_at'])
    date_failed = format_issue_instant_for_mailers(msg['failed_at'])

    notify_client.send_email(
      recipient_identifier: { id_value: icn, id_type: 'ICN' },
      template_id: MAILER_TEMPLATE_ID,
      personalisation: { first_name:, filename:, date_submitted:, date_failed: }
    )

    ::Rails.logger.info('Lighthouse::DocumentUpload exhaustion handler email sent')
    StatsD.increment('silent_failure_avoided_no_confirmation', tags: DD_ZSF_TAGS)
  rescue => e
    ::Rails.logger.error('Lighthouse::DocumentUpload exhaustion handler email error',
                         { message: e.message })
    StatsD.increment('silent_failure', tags: DD_ZSF_TAGS)
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

  def self.notify_client
    VaNotify::Service.new(NOTIFY_SETTINGS.api_key)
  end

  def perform(user_icn, document_hash, user_account_uuid, claim_id, tracked_item_id)
    @user_icn = user_icn
    @document_hash = document_hash

    evidence_submission = record_evidence_submission(claim_id, jid, tracked_item_id, user_account_uuid)
    initialize_upload_document

    Datadog::Tracing.trace('Sidekiq Upload Document') do |span|
      span.set_tag('Document File Size', file_body.size)
      response = client.upload_document(file_body, document) # returns upload response which includes requestId
      request_successful = response.dig(:data, :success)
      if request_successful
        request_id = response.dig(:data, :requestId)
        evidence_submission.update(request_id:)
      else
        raise StandardError
      end
    end
    Datadog::Tracing.trace('Remove Upload Document') do
      uploader.remove!
    end
  end

  private

  def initialize_upload_document
    Datadog::Tracing.trace('Config/Initialize Upload Document') do
      Sentry.set_tags(source: 'documents-upload')
      validate_document!
      uploader.retrieve_from_store!(document.file_name)
    end
  end

  def validate_document!
    raise Common::Exceptions::ValidationErrors, document unless document.valid?
  end

  def client
    @client ||= BenefitsDocuments::WorkerService.new
  end

  def document
    @document ||= LighthouseDocument.new(document_hash)
  end

  def uploader
    @uploader ||= LighthouseDocumentUploader.new(user_icn, document.uploader_ids)
  end

  def perform_initial_file_read
    Datadog::Tracing.trace('Sidekiq read_for_upload') do
      uploader.read_for_upload
    end
  end

  def file_body
    @file_body ||= perform_initial_file_read
  end

  def record_evidence_submission(claim_id, job_id, tracked_item_id, user_account_uuid)
    user_account = UserAccount.find(user_account_uuid)
    job_class = self.class.to_s
    upload_status = BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]

    evidence_submission = EvidenceSubmission.find_or_create_by(claim_id:,
                                                               tracked_item_id:,
                                                               job_id:,
                                                               job_class:,
                                                               upload_status:)
    evidence_submission.user_account = user_account
    evidence_submission.save!
    evidence_submission
  end
end
