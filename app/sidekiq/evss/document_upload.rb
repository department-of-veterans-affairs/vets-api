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

  DD_ZSF_TAGS = ['service:claim-status', 'function: evidence upload to EVSS'].freeze

  attr_accessor :auth_headers, :user_uuid, :document_hash

  wrap_with_logging(
    :pull_file_from_cloud!,
    :perform_initial_file_read,
    :perform_document_upload_to_evss,
    :clean_up!,
    additional_class_logs: {
      form: 'Benefits Document Upload to EVSS API',
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
    # Grab the evidence_submission_id from the msg args
    evidence_submission = EvidenceSubmission.find_by(id: msg['args'][3])

    if can_update_evidence_submission(evidence_submission)
      update_evidence_submission_for_failure(evidence_submission, msg)
    else
      call_failure_notification(msg)
    end
  end

  def perform(auth_headers, user_uuid, document_hash, evidence_submission_id = nil)
    @auth_headers = auth_headers
    @user_uuid = user_uuid
    @document_hash = document_hash

    validate_document!
    pull_file_from_cloud!
    evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_id)
    if self.class.can_update_evidence_submission(evidence_submission)
      update_evidence_submission_with_job_details(evidence_submission)
    end
    perform_document_upload_to_evss
    if self.class.can_update_evidence_submission(evidence_submission)
      update_evidence_submission_for_success(evidence_submission)
    end
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

  def self.update_evidence_submission_for_failure(evidence_submission, msg)
    current_personalisation = JSON.parse(evidence_submission.template_metadata)['personalisation']
    evidence_submission.update!(
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
      failed_date: DateTime.current,
      acknowledgement_date: (DateTime.current + 30.days),
      error_message: 'EVSS::DocumentUpload document upload failure',
      template_metadata: {
        personalisation: update_personalisation(current_personalisation, msg['failed_at'])
      }.to_json
    )
    add_log('FAILED', evidence_submission.claim_id, evidence_submission.id, msg['jid'])
    message = "#{name} EvidenceSubmission updated"
    StatsD.increment('silent_failure_avoided_no_confirmation',
                     tags: ['service:claim-status', "function: #{message}"])
  rescue => e
    error_message = "#{name} failed to update EvidenceSubmission"
    ::Rails.logger.error(error_message, { message: e.message })
    StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
  end

  def self.call_failure_notification(msg)
    return unless Flipper.enabled?(:cst_send_evidence_failure_emails)

    icn = UserAccount.find(msg['args'][1]).icn

    EVSS::FailureNotification.perform_async(icn, create_personalisation(msg))

    ::Rails.logger.info('EVSS::DocumentUpload exhaustion handler email queued')
    StatsD.increment('silent_failure_avoided_no_confirmation', tags: DD_ZSF_TAGS)
  rescue => e
    ::Rails.logger.error('EVSS::DocumentUpload exhaustion handler email error',
                         { message: e.message })
    StatsD.increment('silent_failure', tags: DD_ZSF_TAGS)
    log_exception_to_sentry(e)
  end

  # Update personalisation here since an evidence submission record was previously created
  def self.update_personalisation(current_personalisation, failed_at)
    personalisation = current_personalisation.clone
    personalisation['date_failed'] = helpers.format_date_for_mailers(failed_at)
    personalisation
  end

  # This will be used by EVSS::FailureNotification
  def self.create_personalisation(msg)
    first_name = msg['args'][0]['va_eauth_firstName'].titleize unless msg['args'][0]['va_eauth_firstName'].nil?
    document_type = EVSSClaimDocument.new(msg['args'][2]).description
    # Obscure the file name here since this will be used to generate a failed email
    # NOTE: the template that we use for va_notify.send_email uses `filename` but we can also pass in `file_name`
    filename = helpers.generate_obscured_file_name(msg['args'][2]['file_name'])
    date_submitted = helpers.format_date_for_mailers(msg['created_at'])
    date_failed = helpers.format_date_for_mailers(msg['failed_at'])

    { first_name:, document_type:, filename:, date_submitted:, date_failed: }
  end

  def self.helpers
    BenefitsDocuments::Utilities::Helpers
  end

  def self.add_log(type, claim_id, evidence_submission_id, job_id)
    ::Rails.logger.info("EVSS - Updated Evidence Submission Record to #{type}", {
                          claim_id:,
                          evidence_submission_id:,
                          job_id:
                        })
  end

  def self.can_update_evidence_submission(evidence_submission)
    Flipper.enabled?(:cst_send_evidence_submission_failure_emails) && !evidence_submission.nil?
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

  def update_evidence_submission_with_job_details(evidence_submission)
    evidence_submission.update!(
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:QUEUED],
      job_id: jid,
      job_class: self.class
    )
    StatsD.increment('cst.evss.document_uploads.evidence_submission_record_updated.queued')
    self.class.add_log('QUEUED', evidence_submission.claim_id, evidence_submission.id, jid)
  end

  def update_evidence_submission_for_success(evidence_submission)
    evidence_submission.update!(
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS],
      delete_date: (DateTime.current + 60.days)
    )
    StatsD.increment('cst.evss.document_uploads.evidence_submission_record_updated.success')
    self.class.add_log('SUCCESS', evidence_submission.claim_id, evidence_submission.id, jid)
  end
end
