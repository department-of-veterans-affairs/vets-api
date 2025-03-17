# frozen_string_literal: true

require 'datadog'
require 'timeout'
require 'lighthouse/benefits_documents/worker_service'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

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
        # Grab the evidence_submission_id from the msg args
        evidence_submission = EvidenceSubmission.find_by(id: msg['args'][2])
        if can_update_evidence_submission(evidence_submission)
          update_evidence_submission_for_failure(evidence_submission, msg)
        else
          call_failure_notification(msg)
        end
      end

      def perform(user_icn, document_hash, evidence_submission_id = nil)
        @user_icn = user_icn
        @document_hash = document_hash

        initialize_upload_document
        evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_id)
        if self.class.can_update_evidence_submission(evidence_submission)
          update_evidence_submission_with_job_details(evidence_submission)
        end
        perform_document_upload_to_lighthouse(evidence_submission)
        clean_up!
      end

      def self.verify_msg(msg)
        raise StandardError, "Missing fields in #{name}" if invalid_msg_fields?(msg) || invalid_msg_args?(msg['args'])
      end

      def self.invalid_msg_fields?(msg)
        !(%w[jid args created_at failed_at] - msg.keys).empty?
      end

      def self.invalid_msg_args?(args)
        return true unless args[1].is_a?(Hash)

        !(%w[first_name claim_id document_type file_name tracked_item_id] - args[1].keys).empty?
      end

      def self.update_evidence_submission_for_failure(evidence_submission, msg)
        current_personalisation = JSON.parse(evidence_submission.template_metadata)['personalisation']
        evidence_submission.update!(
          upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
          failed_date: DateTime.current,
          acknowledgement_date: (DateTime.current + 30.days),
          error_message: 'Lighthouse::EvidenceSubmissions::DocumentUpload document upload failure',
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

        icn = msg['args'].first

        Lighthouse::FailureNotification.perform_async(icn, create_personalisation(msg))

        ::Rails.logger.info("#{name} exhaustion handler email queued")
        StatsD.increment('silent_failure_avoided_no_confirmation',
                         tags: ['service:claim-status', 'function: evidence upload to Lighthouse'])
      rescue => e
        ::Rails.logger.error("#{name} exhaustion handler email error",
                             { message: e.message })
        StatsD.increment('silent_failure', tags: ['service:claim-status', 'function: evidence upload to Lighthouse'])
        log_exception_to_sentry(e)
      end

      # Update personalisation here since an evidence submission record was previously created
      def self.update_personalisation(current_personalisation, failed_at)
        personalisation = current_personalisation.clone
        personalisation['date_failed'] = helpers.format_date_for_mailers(failed_at)
        personalisation
      end

      # This will be used by Lighthouse::FailureNotification
      def self.create_personalisation(msg)
        first_name = msg['args'][1]['first_name'].titleize unless msg['args'][1]['first_name'].nil?
        document_type = LighthouseDocument.new(msg['args'][1]).description
        # Obscure the file name here since this will be used to generate a failed email
        # NOTE: the template that we use for va_notify.send_email uses `filename` but we can also pass in `file_name`
        filename = helpers.generate_obscured_file_name(msg['args'][1]['file_name'])
        date_submitted = helpers.format_date_for_mailers(msg['created_at'])
        date_failed = helpers.format_date_for_mailers(msg['failed_at'])

        { first_name:, document_type:, filename:, date_submitted:, date_failed: }
      end

      def self.helpers
        BenefitsDocuments::Utilities::Helpers
      end

      def self.add_log(type, claim_id, evidence_submission_id, job_id)
        ::Rails.logger.info("LH - Updated Evidence Submission Record to #{type}", {
                              claim_id:,
                              evidence_submission_id:,
                              job_id:
                            })
      end

      def self.can_update_evidence_submission(evidence_submission)
        Flipper.enabled?(:cst_send_evidence_submission_failure_emails) && !evidence_submission.nil?
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

      def perform_document_upload_to_lighthouse(evidence_submission)
        Datadog::Tracing.trace('Sidekiq Upload Document') do |span|
          span.set_tag('Document File Size', file_body.size)
          response = client.upload_document(file_body, document) # returns upload response which includes requestId
          if self.class.can_update_evidence_submission(evidence_submission)
            update_evidence_submission_for_in_progress(response, evidence_submission)
          end
        end
      end

      def clean_up!
        Datadog::Tracing.trace('Remove Upload Document') do
          uploader.remove!
        end
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

      def update_evidence_submission_with_job_details(evidence_submission)
        evidence_submission.update!(
          upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:QUEUED],
          job_id: jid,
          job_class: self.class
        )
        StatsD.increment('cst.lighthouse.document_uploads.evidence_submission_record_updated.queued')
        self.class.add_log('QUEUED', evidence_submission.claim_id, evidence_submission.id, jid)
      end

      # For lighthouse uploads if the response is successful then we leave the upload_status as PENDING
      # and the polling job in Lighthouse::EvidenceSubmissions::EvidenceSubmissionDocumentUploadPollingJob
      # will then make a call to lighthouse later to check on the status of the upload and update accordingly
      def update_evidence_submission_for_in_progress(response, evidence_submission)
        request_successful = response.body.dig('data', 'success')
        if request_successful
          request_id = response.body.dig('data', 'requestId')
          evidence_submission.update!(
            request_id:,
            upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]
          )
          StatsD.increment('cst.lighthouse.document_uploads.evidence_submission_record_updated.added_request_id')
          self.class.add_log('PENDING', evidence_submission.claim_id, evidence_submission.id, jid)
        else
          raise StandardError
        end
      end
    end
  end
end
