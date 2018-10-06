# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526
      include Sidekiq::Worker
      include SentryLogging
      include JobStatus

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 13 will result in a run time of ~25 hours
      RETRY = 13
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        transaction_class.update_transaction(msg['jid'], :exhausted)
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
      # @param submission_data [Hash] The submission hash
      #
      def perform(user_uuid, auth_headers, saved_claim_id, submission_data)
        @user_uuid = user_uuid
        @auth_headers = auth_headers
        @saved_claim_id = saved_claim_id
        @submission_data = submission_data

        transaction = find_or_create_transaction
        @submission_id = transaction.submission.id

        with_tracking('Form526 Submission', @saved_claim_id, @submission_id) do
          response = service(@auth_headers).submit_form526(@submission_data['form526'])
          success_handler(response)
        end
      rescue EVSS::DisabilityCompensationForm::ServiceException => e
        non_retryable_error_handler(e)
      rescue Common::Exceptions::GatewayTimeout => e
        gateway_timeout_handler(e)
      rescue StandardError => e
        standard_error_handler(e)
      ensure
        metrics.increment_try
      end

      private

      def find_or_create_transaction
        transaction = transaction_class.find_transaction(jid)
        return transaction if transaction.present?
        saved_claim(@saved_claim_id).async_transaction = transaction_class.start(
          @user_uuid, @auth_headers['va_eauth_dodedipnid'], jid
        )
      end

      def success_handler(response)
        submission_rate_limiter.increment
        metrics.increment_success
        transaction_class.update_transaction(jid, :received, response.attributes)

        perform_submit_uploads(response) if @submission_data['form526_uploads'].present?
        perform_submit_form_4142(response) if @submission_data['form4142'].present?
        perform_cleanup
      end

      def perform_submit_uploads(response)
        EVSS::DisabilityCompensationForm::SubmitUploads.start(
          @auth_headers, response.claim_id, @saved_claim_id, @submission_id, @submission_data['form526_uploads']
        )
      end

      def perform_submit_form_4142(response)
        CentralMail::SubmitForm4142Job.perform_async(
          response.claim_id, @saved_claim_id, @submission_id, @submission_data['form4142']
        )
      end

      def perform_cleanup
        EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(@user_uuid)
      end

      def non_retryable_error_handler(error)
        transaction_class.update_transaction(jid, :non_retryable_error, error.messages)
        log_exception_to_sentry(error, status: :non_retryable_error, jid: jid)
        metrics.increment_non_retryable(error)
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
