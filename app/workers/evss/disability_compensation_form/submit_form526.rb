# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526
      include Sidekiq::Worker
      include JobStatus

      TRANSACTION_CLASS = AsyncTransaction::EVSS::VA526ezSubmitTransaction

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 13 will result in a run time of ~25 hours
      RETRY = 13
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        TRANSACTION_CLASS.update_transaction(msg['jid'], :exhausted)
        log_message_to_sentry(
          "Failed all retries on Form526 submit, last error: #{msg['error_message']}",
          :error
        )
        Metrics.new(self.class::STATSD_KEY_PREFIX, msg['jid']).increment_exhausted
      end

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param user_uuid [String] The user's uuid thats associated with the form
      # @param auth_headers [Hash] The VAAFI headers for the user
      # @param saved_claim_id [String] The claim id for the claim that will be associated with the async transaction
      # @param submission_data [Hash] The submission hash of 526, uploads, and 4142 data
      #
      def perform(user_uuid, auth_headers, saved_claim_id, submission_data)
        @user_uuid = user_uuid
        @auth_headers = auth_headers
        @saved_claim_id = saved_claim_id
        @submission_data = submission_data

        transaction = find_or_create_transaction
        @submission_id = transaction.submission.id

        with_tracking('Form526 Submission', @saved_claim_id, @submission_id) do
          # Subclass is expected to implement #service
          # `increase only` and `all claims` will have separate EVSS services endpoints
          # TODO: sub classed #service can be removed once `increase only` has been deprecated
          response = service(@auth_headers).submit_form526(@submission_data['form526'])
          success_handler(response)
        end
      rescue Common::Exceptions::GatewayTimeout => e
        retryable_error_handler(e)
      rescue StandardError => e
        non_retryable_error_handler(e)
      end

      private

      def find_or_create_transaction
        transaction = TRANSACTION_CLASS.find_transaction(jid)
        return transaction if transaction.present?
        saved_claim(@saved_claim_id).async_transaction = TRANSACTION_CLASS.start(
          @user_uuid, @auth_headers['va_eauth_dodedipnid'], jid
        )
      end

      def success_handler(response)
        submission_rate_limiter.increment
        TRANSACTION_CLASS.update_transaction(jid, :received, response.attributes)

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
        message = error.try(:messages) || { error: error.message }
        TRANSACTION_CLASS.update_transaction(jid, :non_retryable_error, message)
        super(error)
      end

      def retryable_error_handler(error)
        TRANSACTION_CLASS.update_transaction(jid, :retrying, error: error.message)
        super(error)
        raise EVSS::DisabilityCompensationForm::GatewayTimeout, error.message
      end

      def service(auth_headers)
        EVSS::DisabilityCompensationForm::Service.new(
          auth_headers
        )
      end

      def saved_claim(saved_claim_id)
        SavedClaim::DisabilityCompensation.find(saved_claim_id)
      end

      def submission_rate_limiter
        Common::EventRateLimiter.new(REDIS_CONFIG['evss_526_submit_form_rate_limit'])
      end
    end
  end
end
