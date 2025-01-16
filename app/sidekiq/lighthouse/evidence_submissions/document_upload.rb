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

        if Flipper.enabled?(:cst_send_evidence_submission_failure_emails)
          update_evidence_submission_for_failure(msg)
        else
          call_failure_notification(msg)
        end
      end

      def perform(user_icn, document_hash)
        @user_icn = user_icn
        @document_hash = document_hash
        document = LighthouseDocument.new document_hash
        initialize_upload_document
        Datadog::Tracing.trace('Sidekiq Upload Document') do |span|
          span.set_tag('Document File Size', file_body.size)
          response = client.upload_document(file_body, document) # returns upload response which includes requestId
          if Flipper.enabled?(:cst_send_evidence_submission_failure_emails)
            update_evidence_submission_for_success(jid, response)
          end
        end
        Datadog::Tracing.trace('Remove Upload Document') do
          uploader.remove!
        end
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

      def self.update_evidence_submission_for_failure(msg)
        evidence_submission = EvidenceSubmission.find_by(job_id: msg['jid'])
        evidence_submission.update(
          upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
          template_metadata_ciphertext: {
            personalisation: update_personalisation(evidence_submission, msg['failed_at'])
          }.to_json
        )
        message = "#{name} EvidenceSubmission updated"
        ::Rails.logger.info(message)
        StatsD.increment('silent_failure_avoided_no_confirmation',
                         tags: ['service:claim-status', "function: #{message}"])
      rescue => e
        error_message = "#{name} failed to update EvidenceSubmission"
        ::Rails.logger.info(error_message, { messsage: e.message })
        StatsD.increment('silent_failure', tags: ['service:claim-status', "function: #{error_message}"])
      end

      def self.call_failure_notification(msg)
        icn = msg['args'].first

        Lighthouse::FailureNotification.perform_async(icn, personalisation: create_personalisation(msg))

        ::Rails.logger.info("#{name} exhaustion handler email queued")
        StatsD.increment('silent_failure_avoided_no_confirmation',
                         tags: ['service:claim-status', 'function: evidence upload to Lighthouse'])
      rescue => e
        ::Rails.logger.error("#{name} exhaustion handler email error",
                             { message: e.message })
        StatsD.increment('silent_failure', tags: ['service:claim-status', 'function: evidence upload to Lighthouse'])
        log_exception_to_sentry(e)
      end

      def self.format_issue_instant_for_mailers(issue_instant)
        # We want to return all times in EDT
        timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

        # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
        timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
      end

      # Update personalisation here since an evidence submission record was previously created
      def self.update_personalisation(current_personalisation, failed_at)
        personalisation = current_personalisation.clone
        personalisation.failed_date = format_issue_instant_for_mailers(failed_at)
        personalisation
      end

      # This will be used by Lighthouse::FailureNotification
      def self.create_personalisation(msg)
        first_name = msg['args'][1]['first_name'].titleize unless msg['args'][1]['first_name'].nil?
        document_type = msg['args'][1]['document_type']
        # Obscure the file name here since this will be used to generate a failed email
        file_name = BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(msg['args'][1]['file_name'])
        date_submitted = format_issue_instant_for_mailers(msg['created_at'])
        date_failed = format_issue_instant_for_mailers(msg['failed_at'])

        { first_name:, document_type:, file_name:, date_submitted:, date_failed: }
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

      def update_evidence_submission_for_success(job_id, response)
        evidence_submission = EvidenceSubmission.find_by(job_id:)
        request_successful = response.dig(:data, :success)
        if request_successful
          request_id = response.dig(:data, :requestId)
          evidence_submission.update(
            upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS],
            request_id:
          )
          evidence_submission.save!
        else
          raise StandardError
        end
      end
    end
  end
end
