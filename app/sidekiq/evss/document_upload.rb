# frozen_string_literal: true

require 'datadog'
require 'timeout'
require 'logging/third_party_transaction'
require 'evss/failure_notification'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

class EVSS::DocumentUpload
  include Sidekiq::Job
  extend SentryLogging
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
  sidekiq_options retry: 16, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  sidekiq_retries_exhausted do |msg, _ex|
    verify_msg(msg)

    if Flipper.enabled?('cst_send_evidence_submission_failure_emails')
      update_evidence_submission(msg)
    else
      call_failure_notification(msg)
    end
  end

  def perform(auth_headers, user_uuid, document_hash)
    @auth_headers = auth_headers
    @user_uuid = user_uuid
    @document_hash = document_hash

    validate_document!
    pull_file_from_cloud!
    perform_document_upload_to_evss
    update_evidence_submission_status(jid) if Flipper.enabled?('cst_send_evidence_submission_failure_emails')
    clean_up!
  end

  def self.verify_msg(msg)
    raise StandardError, "Missing fields in #{name}" if invalid_msg_fields?(msg) || invalid_msg_args?(msg['args'])
  end

  def self.invalid_msg_fields?(msg)
    !(%w[jid args created_at failed_at] - msg.keys).empty?
  end

  def self.invalid_msg_args?(args)
    return true unless args[0].is_a?(Hash)

    return true unless args[2].is_a?(Hash)

    return true if args[0]['va_eauth_firstName'].empty?

    !(%w[evss_claim_id tracked_item_id document_type file_name] - args[2].keys).empty?
  end

  def self.update_evidence_submission(msg)
    evidence_submission = EvidenceSubmission.find_by(job_id: msg['jid'])
    evidence_submission.update(
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
      template_metadata_ciphertext: {
        personalisation: update_personalisation(evidence_submission, msg['failed_at'])
      }.to_json
    )
  rescue => e
    error_message = "#{name} failed to update EvidenceSubmission"
    ::Rails.logger.info(error_message, { messsage: e.message })
    StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
  end

  def self.call_failure_notification(msg)
    return unless Flipper.enabled?('cst_send_evidence_failure_emails')

    icn = UserAccount.find(msg['args'][1]).icn

    EVSS::FailureNotification.perform_async(icn, personalisation: create_personalisation(msg))

    ::Rails.logger.info('EVSS::DocumentUpload exhaustion handler email queued')
    StatsD.increment('silent_failure_avoided_no_confirmation', tags: DD_ZSF_TAGS)
  rescue => e
    ::Rails.logger.error('EVSS::DocumentUpload exhaustion handler email error',
                         { message: e.message })
    StatsD.increment('silent_failure', tags: ['service:claim-status', 'function: evidence upload to EVSS'])
    log_exception_to_sentry(e)
  end

  # Update personalisation here since an evidence submission record was previously created
  def self.update_personalisation(current_personalisation, failed_at)
    personalisation = current_personalisation.clone
    personalisation.failed_date = format_issue_instant_for_mailers(failed_at)
    personalisation
  end

  # This will be used by EVSS::FailureNotification
  def self.create_personalisation(msg)
    first_name = msg['args'][0]['va_eauth_firstName'].titleize unless msg['args'][0]['va_eauth_firstName'].nil?
    document_type = msg['args'][2]['document_type']
    # Obscure the file name here since this will be used to generate a failed email
    file_name = BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(msg['args'][2]['file_name'])
    date_submitted = format_issue_instant_for_mailers(msg['created_at'])
    date_failed = format_issue_instant_for_mailers(msg['failed_at'])

    { first_name:, document_type:, file_name:, date_submitted:, date_failed: }
  end

  def self.format_issue_instant_for_mailers(issue_instant)
    # We want to return all times in EDT
    timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end

  # This method allows format_issue_instant_for_mailers to be used by update_evidence_submission_status
  # and by the self methods called in sidekiq_retries_exhausted
  def format_issue_instant_for_mailers(issue_instant)
    self.class.format_issue_instant_for_mailers(issue_instant)
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

  def update_evidence_submission_status(job_id)
    evidence_submission = EvidenceSubmission.find_by(job_id:)
    evidence_submission.update(
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]
    )
    evidence_submission.save!
    evidence_submission
  end
end
