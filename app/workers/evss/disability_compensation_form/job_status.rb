# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    module JobStatus
      extend ActiveSupport::Concern
      include SentryLogging

      def with_tracking(job_title, saved_claim_id, submission_id)
        @status_job_title = job_title
        @status_saved_claim_id = saved_claim_id
        @status_submission_id = submission_id

        job_try
        yield
        job_success
      end

      def job_try
        upsert_job_status(Form526JobStatus::STATUS[:try])
        log_info('try')
        metrics.increment_try
      end

      def job_success
        upsert_job_status(Form526JobStatus::STATUS[:success])
        log_info('success')
        metrics.increment_success
      end

      def retryable_error_handler(error)
        upsert_job_status(Form526JobStatus::STATUS[:retryable_error], error)
        log_error('retryable_error', error)
        metrics.increment_retryable(error)
      end

      def non_retryable_error_handler(error)
        upsert_job_status(Form526JobStatus::STATUS[:non_retryable_error], error)
        log_exception_to_sentry(error, status: :non_retryable_error, jid: jid)
        log_error('non_retryable_error', error)
        metrics.increment_non_retryable(error)
      end

      private

      def upsert_job_status(status, error = nil)
        values = {
          form526_submission_id: @status_submission_id,
          job_id: jid,
          job_class: klass,
          status: status,
          updated_at: Time.now.utc
        }
        values[:error_message] = error.try(:messages) || error.message if error
        Form526JobStatus.upsert({ job_id: jid }, values)
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
        @metrics ||= Metrics.new(self.class::STATSD_KEY_PREFIX, jid)
      end
    end
  end
end
