# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526
      include Sidekiq::Worker
      include SentryLogging
      include StepTracking

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 13 will result in a run time of ~25 hours
      RETRY = 13
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        transaction_class.update_transaction(jid, :exhausted)
        log_message_to_sentry(
          "Failed all retries on Form526 submit, last error: #{msg['error_message']}",
          :error
        )
        metrics.increment_exhausted
      end

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param user_uuid [String] The user's uuid thats associated with the form
      # @param auth_headers [Hash] The VAAFI headers for the user
      # @param saved_claim_id [String] The claim id for the claim that will be associated with the async transaction
      # @param form_content [Hash] The form content that is to be submitted
      # @param form4142 [Hash] The form content for 4142 that is to be submitted
      # @param uploads [Hash] The users ancillary uploads that will be submitted separately
      #
      # rubocop:disable Metrics/ParameterLists
      def perform(user_uuid, auth_headers, saved_claim_id, form_content, form4142, uploads)
        with_tracking(saved_claim_id) do
          associate_transaction(auth_headers, saved_claim_id, user_uuid) if transaction_class.find_transaction(jid).blank?
          response = service(auth_headers).submit_form526(form_content)
          submit_4142(form4142, user_uuid, auth_headers, response.claim_id, saved_claim_id) if form4142
          success_handler(user_uuid, auth_headers, saved_claim_id, response, uploads)
        end
      rescue EVSS::DisabilityCompensationForm::ServiceException => e
        retryable_error_handler(e) if e.status_code.between?(500, 600)
        non_retryable_error_handler(e)
      rescue Common::Exceptions::GatewayTimeout => e
        gateway_timeout_handler(e)
      rescue StandardError => e
        standard_error_handler(e)
      ensure
        metrics.increment_try
      end
      # rubocop:enable Metrics/ParameterLists

      private

      def success_handler(user_uuid, auth_headers, saved_claim_id, response, uploads)
        submission_rate_limiter.increment
        metrics.increment_success
        transaction_class.update_transaction(jid, :received, response.attributes)

        Rails.logger.info('Form526 Submission',
                          'user_uuid' => user_uuid,
                          'saved_claim_id' => saved_claim_id,
                          'job_id' => jid,
                          'job_status' => 'received')

        EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(user_uuid)

        if uploads.present?
          EVSS::DisabilityCompensationForm::SubmitUploads.start(
            auth_headers, response.claim_id, uploads
          )
        end
      end

      def non_retryable_error_handler(error)
        transaction_class.update_transaction(jid, :non_retryable_error, error.messages)
        log_exception_to_sentry(error, status: :non_retryable_error, jid: jid)
        metrics.increment_non_retryable(error)
      end

      def retryable_error_handler(error)
        transaction_class.update_transaction(jid, :retrying, error.messages)
        metrics.increment_retryable(error)
        raise error
      end

      def gateway_timeout_handler(error)
        transaction_class.update_transaction(jid, :retrying, error.message)
        metrics.increment_retryable(error)
        raise EVSS::DisabilityCompensationForm::GatewayTimeout, error.message
      end

      def standard_error_handler(error)
        transaction_class.update_transaction(jid, :non_retryable_error, error.to_s)
        extra_content = { status: :non_retryable_error, jid: jid }
        log_exception_to_sentry(error, extra_content)
        metrics.increment_non_retryable(error)
      end

      def associate_transaction(auth_headers, claim_id, user_uuid)
        saved_claim(claim_id).async_transaction = transaction_class.start(
          user_uuid, auth_headers['va_eauth_dodedipnid'], jid
        )
      end

      def submit_4142(form_content, user_uuid, auth_headers, evss_claim_id, saved_claim_id)
        saved_claim_created_at = saved_claim(saved_claim_id).created_at
        CentralMail::SubmitForm4142Job.perform_async(
          user_uuid, auth_headers, form_content, evss_claim_id, saved_claim_created_at
        )
      end

      def service(auth_headers)
        EVSS::DisabilityCompensationForm::Service.new(
          auth_headers
        )
      end

      def saved_claim(saved_claim_id)
        SavedClaim::DisabilityCompensation.find(saved_claim_id)
      end

      def transaction_class
        AsyncTransaction::EVSS::VA526ezSubmitTransaction
      end

      def submission_rate_limiter
        Common::EventRateLimiter.new(REDIS_CONFIG['evss_526_submit_form_rate_limit'])
      end

      def metrics
        @metrics ||= Metrics.new(STATSD_KEY_PREFIX, jid)
      end
    end
  end
end
