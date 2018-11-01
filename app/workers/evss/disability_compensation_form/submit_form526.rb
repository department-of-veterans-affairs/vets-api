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
        Rails.logger.error('Form526 Exhausted', 'job_id' => msg['jid'], 'error_message' => msg['error_message'])
        Metrics.new(STATSD_KEY_PREFIX, msg['jid']).increment_exhausted
      end

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param user_uuid [String] The user's uuid thats associated with the form
      # @param auth_headers [Hash] The VAAFI headers for the user
      # @param saved_claim_id [String] The claim id for the claim that will be associated with the async transaction
      # @param submission_id [Hash] The submission hash of 526, uploads, and 4142 data
      #
      def perform(user_uuid, auth_headers, saved_claim_id, submission_id)
        @user_uuid = user_uuid
        @auth_headers = auth_headers
        @saved_claim_id = saved_claim_id
        @submission_id = submission_id

        with_tracking('Form526 Submission', @saved_claim_id, @submission_id) do
          # TODO: sub classed #service can be removed once `increase only` has been deprecated
          response = service(@auth_headers).submit_form526(submission.form526_to_json)
          response_handler(response)
        end
      rescue Common::Exceptions::GatewayTimeout => e
        retryable_error_handler(e)
      rescue StandardError => e
        non_retryable_error_handler(e)
      end

      def workflow_complete_handler(_status, options)
        submission = saved_claim(options['saved_claim_id']).submission
        submission.complete = true
        submission.save
      end

      private

      def submission
        @submission ||= Form526Submission.find(@submission_id)
      end

      def response_handler(response)
        submission_rate_limiter.increment
        submission.perform_ancillary_jobs(response.claim_id)
      end

      def retryable_error_handler(error)
        super(error)
        raise EVSS::DisabilityCompensationForm::GatewayTimeout, error.message
      end

      def service(_auth_headers)
        raise NotImplementedError, 'Subclass of SubmitForm526 must implement #service'
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
