# frozen_string_literal: true

require 'sidekiq/form526_backup_submission_process/submit'
require 'sidekiq/form526_job_status_tracker/metrics'
require 'sidekiq/form526_job_status_tracker/backup_submission'

module Sidekiq
  module Form526JobStatusTracker
    # rubocop:disable Metrics/ModuleLength
    module JobTracker
      extend ActiveSupport::Concern
      extend BackupSubmission
      include SentryLogging

      STATSD_KEY_PREFIX = 'worker.evss.submit_form526.job_status'

      class_methods do
        # Callback that fires when a job has exhausted its retries
        #
        # @param msg [Hash] The message payload from Sidekiq
        #
        # rubocop:disable Metrics/MethodLength
        def job_exhausted(msg, statsd_key_prefix)
          job_id = msg['jid']
          job_class = msg['class'].demodulize
          error_class = msg['error_class']
          error_message = msg['error_message']
          timestamp = Time.now.utc
          form526_submission_id = msg['args'].first

          form_job_status = Form526JobStatus.find_by(job_id:)
          bgjob_errors = form_job_status.bgjob_errors || {}
          new_error = {
            "#{timestamp.to_i}": {
              caller_method: __method__.to_s,
              error_class:,
              error_message:,
              timestamp:,
              form526_submission_id:
            }
          }

          JobTracker.send_backup_submission_if_enabled(form526_submission_id:, job_class:, job_id:,
                                                       error_message:, error_class:)

          form_job_status.update(
            status: Form526JobStatus::STATUS[:exhausted],
            bgjob_errors: bgjob_errors.merge(new_error)
          )

          ::Rails.logger.warn(
            'Submit Form 526 Retries exhausted',
            { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
          )
        rescue => e
          ::Rails.logger.error(
            'Failure in SubmitForm526#sidekiq_retries_exhausted',
            {
              messaged_content: e.message,
              job_id:,
              submission_id: form526_submission_id,
              pre_exhaustion_failure: {
                error_class:,
                error_message:
              }
            }
          )
          raise e
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
      # @param service_provider [String] Either 'lighthouse' or 'evss'
      #
      def with_tracking(job_title, saved_claim_id, submission_id, is_bdd = nil, service_provider = nil)
        @status_job_title = job_title
        @status_saved_claim_id = saved_claim_id
        @status_submission_id = submission_id
        @is_bdd = is_bdd
        @service_provider = service_provider

        job_try
        begin
          yield
        rescue
          exception_raised = true
          raise
        ensure
          job_status = Form526JobStatus.find_by(job_id: jid)
          job_success unless exception_raised || job_status&.error_class
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
        metrics.increment_success(@is_bdd, @service_provider)
      rescue => e
        ::Rails.logger.error('error tracking job success', error: e, class: klass, trace: e.backtrace)
      end

      # Metrics and logging for any retryable errors that occurred.
      # Retryable are system recoverable, e.g. an upstream http timeout
      #
      def retryable_error_handler(error)
        upsert_job_status(Form526JobStatus::STATUS[:retryable_error], error)
        log_error('retryable_error', error)
        metrics.increment_retryable(error, @is_bdd, @service_provider)
      end

      # Metrics and logging for any non-retryable errors that occurred.
      # Non-retryable errors will always fail, e.g. an ArgumentError in the job class
      #
      def non_retryable_error_handler(error)
        upsert_job_status(Form526JobStatus::STATUS[:non_retryable_error], error)
        error_class = error.class
        error_message = error.message
        JobTracker.send_backup_submission_if_enabled(form526_submission_id: @status_submission_id,
                                                     job_class: klass, job_id: jid,
                                                     error_class:, error_message:)
        log_exception_to_sentry(error, status: :non_retryable_error, jid:)
        log_error('non_retryable_error', error)
        metrics.increment_non_retryable(error, @is_bdd, @service_provider)
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
                            'service_provider' => @service_provider,
                            'job_id' => jid,
                            'status' => status)
      end

      def log_error(status, error)
        ::Rails.logger.error(@status_job_title,
                             'saved_claim_id' => @status_saved_claim_id,
                             'submission_id' => @status_submission_id,
                             'service_provider' => @service_provider,
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
