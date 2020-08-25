# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Module that is mixed in to {EVSS::DisabilityCompensationForm::Job} so that it's sub-classes
    # get automatic metrics and logging.
    #
    module JobStatus
      extend ActiveSupport::Concern
      include SentryLogging

      class_methods do
        # Callback that fires when a job has exhausted its retries
        #
        # @param msg [Hash] The message payload from Sidekiq
        #
        def job_exhausted(msg)
          values = {
            form526_submission_id: msg['args'].first,
            job_id: msg['jid'],
            job_class: msg['class'].demodulize,
            status: Form526JobStatus::STATUS[:exhausted],
            error_class: msg['error_class'],
            error_message: msg['error_message'],
            updated_at: Time.now.utc
          }
          Form526JobStatus.upsert(values, unique_by: :job_id)

          Rails.logger.error(
            'Form526 Exhausted', submission_id: msg['args'].first,
                                 job_id: msg['jid'],
                                 error_class: msg['error_class'],
                                 error_message: msg['error_message']
          )
          Metrics.new(STATSD_KEY_PREFIX).increment_exhausted
        rescue => e
          Rails.logger.error('error tracking job exhausted', error: e, class: msg['class'].demodulize)
        end
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
        yield
        job_success
      end

      # Metrics and logging for each Sidekiq try
      #
      def job_try
        upsert_job_status(Form526JobStatus::STATUS[:try])
        log_info('try')
        metrics.increment_try
      rescue => e
        Rails.logger.error('error tracking job try', error: e, class: klass)
      end

      # Metrics and logging for when the job succeeds
      #
      def job_success
        upsert_job_status(Form526JobStatus::STATUS[:success])
        log_info('success')
        metrics.increment_success
      rescue => e
        Rails.logger.error('error tracking job success', error: e, class: klass)
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
        log_exception_to_sentry(error, status: :non_retryable_error, jid: jid)
        log_error('non_retryable_error', error)
        metrics.increment_non_retryable(error, @is_bdd)
      end

      private

      def upsert_job_status(status, error = nil)
        values = {
          form526_submission_id: @status_submission_id,
          job_id: jid,
          job_class: klass,
          status: status,
          error_class: nil,
          error_message: nil,
          updated_at: Time.now.utc
        }
        values[:error_class] = error.class if error
        values[:error_message] = error_message(error) if error
        Form526JobStatus.upsert(values, unique_by: :job_id)
      end

      def error_message(error)
        error.try(:messages) ? error.messages.to_s : error.message
      end

      def log_info(status)
        Rails.logger.info(@status_job_title,
                          'saved_claim_id' => @status_saved_claim_id,
                          'submission_id' => @status_submission_id,
                          'job_id' => jid,
                          'status' => status)
      end

      def log_error(status, error)
        Rails.logger.error(@status_job_title,
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
  end
end
