# frozen_string_literal: true

require 'sidekiq/form526_backup_submission_process/submit'
require 'sidekiq/form526_job_status_tracker/metrics'

module Sidekiq
  module Form526JobStatusTracker
    # rubocop:disable Metrics/ModuleLength
    module JobTracker
      extend ActiveSupport::Concern
      include SentryLogging

      class_methods do
        # Callback that fires when a job has exhausted its retries
        #
        # @param msg [Hash] The message payload from Sidekiq
        #
        # rubocop:disable Metrics/MethodLength
        def job_exhausted(msg, statsd_key_prefix)
          job_id = msg['jid']
          error_class = msg['error_class']
          error_message = msg['error_message']
          timestamp = Time.now.utc
          form526_submission_id = msg['args'].first

          values = {
            form526_submission_id:,
            job_id:,
            job_class: msg['class'].demodulize,
            status: Form526JobStatus::STATUS[:exhausted],
            error_class:,
            error_message:,
            bgjob_errors: {},
            updated_at: timestamp
          }

          form_job_status = Form526JobStatus.find_by(job_id:)
          bgjob_errors = form_job_status.bgjob_errors || {}
          new_error = {
            "#{timestamp.to_i}": {
              caller_method: __method__.to_s,
              error_class:, error_message:,
              timestamp:
            }
          }
          bgjob_errors.merge!(new_error)
          values[:bgjob_errors] = bgjob_errors

          # rubocop:disable Rails/SkipsModelValidations
          Form526JobStatus.upsert(values, unique_by: :job_id)
          # rubocop:enable Rails/SkipsModelValidations
          submission_obj ||= Form526Submission.find(form526_submission_id)
          additional_birls_to_try = submission_obj.birls_ids_that_havent_been_tried_yet

          backup_job_jid = nil
          flipper_sym = :form526_backup_submission_temp_killswitch

          # Entry-point for backup 526 CMP submission
          #
          # Required criteria to send a backup 526 submission from here:
          # Enabled in settings and flipper
          # Is an overall submission and NOT an upload attempt
          # Does not have a valid claim ID (through RRD process or otherwise) (protect against dup submissions)
          # Does not have a backup submission ID (protect against dup submissions)
          # Does not have additional birls it is going to try and submit with
          send_backup_submission = Settings.form526_backup.enabled && Flipper.enabled?(flipper_sym) &&
                                   values[:job_class] == 'SubmitForm526AllClaim' &&
                                   submission_obj.submitted_claim_id.nil? &&
                                   additional_birls_to_try.empty? && submission_obj.backup_submitted_claim_id.nil?

          if send_backup_submission
            backup_job_jid = Sidekiq::Form526BackupSubmissionProcess::Submit.perform_async(form526_submission_id)
          end

          vagov_id = JSON.parse(submission_obj.auth_headers_json)['va_eauth_service_transaction_id']
          log_message = {
            submission_id: form526_submission_id,
            job_id:,
            job_class: values[:job_class],
            error_class:,
            error_message:,
            remaining_birls: additional_birls_to_try,
            va_eauth_service_transaction_id: vagov_id
          }
          log_message['backup_job_id'] = backup_job_jid unless backup_job_jid.nil?
          ::Rails.logger.error('Form526 Exhausted or Errored (retryable-error-path)', log_message)
        rescue => e
          emsg = 'Form526 Exhausted, with error tracking job exhausted'
          error_details = {
            message: emsg, error: e,
            class: msg['class'].demodulize, jid: msg['jid'],
            backtrace: e.backtrace
          }
          ::Rails.logger.error(emsg, error_details)
        ensure
          Metrics.new(statsd_key_prefix).increment_exhausted
        end
        # rubocop:enable Metrics/MethodLength
      end

      # Code wrapped by this block will run between the {job_try} and {job_success} methods
      #
      # @param job_title [String] Description of the job being run
      # @param saved_claim_id [Integer] The {SavedClaim} id
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def with_tracking(job_title, saved_claim_id, submission_id, is_bdd = nil)
        @status_job_title = job_title
        @status_saved_claim_id = saved_claim_id
        @status_submission_id = submission_id
        @is_bdd = is_bdd

        job_try
        begin
          yield
        rescue
          exception_raised = true
          raise
        ensure
          job_success unless exception_raised
        end
      end

      # Metrics and logging for each Sidekiq try
      #
      def job_try
        upsert_job_status(Form526JobStatus::STATUS[:try])
        log_info('try')
        metrics.increment_try
      rescue => e
        ::Rails.logger.error('error tracking job try', error: e, class: klass)
      end

      # Metrics and logging for when the job succeeds
      #
      def job_success
        upsert_job_status(Form526JobStatus::STATUS[:success])
        log_info('success')
        metrics.increment_success(@is_bdd)
      rescue => e
        ::Rails.logger.error('error tracking job success', error: e, class: klass)
      end

      # Metrics and logging for any retryable errors that occurred.
      # Retryable are system recoverable, e.g. an upstream http timeout
      #
      def retryable_error_handler(error)
        upsert_job_status(Form526JobStatus::STATUS[:retryable_error], error)
        log_error('retryable_error', error)
        metrics.increment_retryable(error, @is_bdd)
      end

      # Metrics and logging for any non-retryable errors that occurred.
      # Non-retryable errors will always fail, e.g. an ArgumentError in the job class
      #
      def non_retryable_error_handler(error)
        upsert_job_status(Form526JobStatus::STATUS[:non_retryable_error], error)
        log_exception_to_sentry(error, status: :non_retryable_error, jid:)
        log_error('non_retryable_error', error)
        metrics.increment_non_retryable(error, @is_bdd)
      end

      private

      def upsert_job_status(status, error = nil)
        timestamp = Time.now.utc

        values = { form526_submission_id: @status_submission_id,
                   job_id: jid,
                   job_class: klass,
                   status:,
                   error_class: nil,
                   error_message: nil,
                   bgjob_errors: {},
                   updated_at: timestamp }

        caller_method = caller[0][/`.*'/][1..-2]
        error_class = error.class if error
        error_message = error_message(error) if error
        values[:error_class] = error_class
        values[:error_message] = error_message

        values[:bgjob_errors] = update_background_job_errors(job_id: jid,
                                                             error_class:,
                                                             error_message:,
                                                             caller_method:,
                                                             timestamp:)
        # rubocop:disable Rails/SkipsModelValidations
        Form526JobStatus.upsert(values, unique_by: :job_id)
        # rubocop:enable Rails/SkipsModelValidations
      end

      def update_background_job_errors(job_id:, error_class:, error_message:, caller_method:, timestamp: Time.now.utc)
        form_job_status = Form526JobStatus.find_by(job_id:)
        return unless form_job_status

        bgjob_errors = form_job_status.bgjob_errors || {}

        new_error = {
          "#{timestamp.to_i}": {
            caller_method:,
            error_class:,
            error_message:,
            timestamp:
          }
        }

        bgjob_errors.merge!(new_error)
      end

      def error_message(error)
        error.try(:messages) ? error.messages.to_s : error.message
      end

      def log_info(status)
        ::Rails.logger.info(@status_job_title,
                            'saved_claim_id' => @status_saved_claim_id,
                            'submission_id' => @status_submission_id,
                            'job_id' => jid,
                            'status' => status)
      end

      def log_error(status, error)
        ::Rails.logger.error(@status_job_title,
                             'saved_claim_id' => @status_saved_claim_id,
                             'submission_id' => @status_submission_id,
                             'job_id' => jid,
                             'status' => status,
                             'error_message' => error)
      end

      def klass
        self.class.name.demodulize
      end

      def metrics
        @metrics ||= Metrics.new(self.class::STATSD_KEY_PREFIX)
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
