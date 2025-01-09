# frozen_string_literal: true

require 'datadog'
require 'timeout'
require 'lighthouse/benefits_documents/worker_service'
require 'lighthouse/benefits_documents/constants'

module Lighthouse
  module EvidenceSubmissions
    class DocumentUpload
      include Sidekiq::Job

      attr_accessor :user_icn, :document_hash

      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16, queue: 'low'
      # Set minimum retry time to ~1 hour
      sidekiq_retry_in do |count, _exception|
        rand(3600..3660) if count < 9
      end

      sidekiq_retries_exhausted do |msg, _ex|
        verify_msg(msg)

        if Flipper.enabled?('cst_send_evidence_submission_failure_emails')
          create_evidence_submission(msg)
        else
          call_failure_notification(msg)
        end
      end

      def self.format_issue_instant_for_mailers(issue_instant)
        # We want to return all times in EDT
        timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

        # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
        timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
      end

      def perform(user_icn, document_hash, user_account_uuid)
        @user_icn = user_icn
        @document_hash = document_hash
        document = LighthouseDocument.new document_hash

        evidence_submission = record_evidence_submission(document.claim_id, jid, document.tracked_item_id,
                                                         user_account_uuid)
        initialize_upload_document

        Datadog::Tracing.trace('Sidekiq Upload Document') do |span|
          span.set_tag('Document File Size', file_body.size)
          response = client.upload_document(file_body, document) # returns upload response which includes requestId
          if Flipper.enabled?('cst_send_evidence_submission_failure_emails')
            add_request_id(response, evidence_submission)
          end
        end
        Datadog::Tracing.trace('Remove Upload Document') do
          uploader.remove!
        end
      end

      def self.verify_msg(msg)
        if invalid_msg_fields?(msg) || invalid_msg_args?(msg['args'])
          raise StandardError, 'Missing fields in Lighthouse::EvidenceSubmissions::DocumentUpload'
        end
      end

      def self.invalid_msg_fields?(msg)
        !(%w[jid args created_at failed_at] - msg.keys).empty?
      end

      def self.invalid_msg_args?(args)
        return true unless args[1].is_a?(Hash)

        !(%w[first_name claim_id document_type file_name tracked_item_id] - args[1].keys).empty?
      end

      def self.create_evidence_submission(msg)
        job_class = 'Lighthouse::EvidenceSubmissions::DocumentUpload'
        uuid = msg['args'][1]['uuid']
        EvidenceSubmission.create(
          job_id: msg['jid'],
          job_class: 'Lighthouse::EvidenceSubmissions::DocumentUpload',
          claim_id: msg['args'][1]['claim_id'],
          tracked_item_id: msg['args'][1]['tracked_item_id'],
          upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
          user_account: UserAccount.find_or_create_by(id: uuid),
          template_metadata_ciphertext: { personalisation: create_personalisation(msg) }.to_json
        )

        message = "#{job_class} EvidenceSubmission created"
        ::Rails.logger.info(message)
        StatsD.increment('silent_failure_avoided_no_confirmation',
                         tags: ['service:claim-status', "function: #{message}"])
      rescue => e
        error_message = "#{job_class} failed to create EvidenceSubmission"
        ::Rails.logger.info(error_message, { messsage: e.message })
        StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
      end

      def self.call_failure_notification(msg)
        icn = msg['args'].first

        Lighthouse::FailureNotification.perform_async(icn, personalisation: create_personalisation(msg))

        ::Rails.logger.info('Lighthouse::DocumentUpload exhaustion handler email queued')
        StatsD.increment('silent_failure_avoided_no_confirmation',
                         tags: ['service:claim-status', 'function: evidence upload to Lighthouse'])
      rescue => e
        ::Rails.logger.error('Lighthouse::DocumentUpload exhaustion handler email error',
                             { message: e.message })
        StatsD.increment('silent_failure', tags: ['service:claim-status', 'function: evidence upload to Lighthouse'])
        log_exception_to_sentry(e)
      end

      def self.create_personalisation(msg)
        first_name = msg['args'][1]['first_name'].titleize unless msg['args'][1]['first_name'].nil?
        document_type = msg['args'][1]['document_type']
        file_name = msg['args'][1]['file_name']
        date_submitted = format_issue_instant_for_mailers(msg['created_at'])
        date_failed = format_issue_instant_for_mailers(msg['failed_at'])

        { first_name:, document_type:, file_name:, date_submitted:, date_failed: }
      end

      private

      def add_request_id(response, evidence_submission)
        request_successful = response.dig(:data, :success)
        if request_successful
          request_id = response.dig(:data, :requestId)
          evidence_submission.update(request_id:)
        else
          raise StandardError
        end
      end

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
  end
end
