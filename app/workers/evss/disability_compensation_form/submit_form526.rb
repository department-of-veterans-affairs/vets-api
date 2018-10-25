# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526
      include Sidekiq::Worker
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

      def self.start(user_uuid, auth_headers, saved_claim_id, submission_data)
        workflow_batch = Sidekiq::Batch.new
        workflow_batch.on(:success, 'SubmitForm526#complete', 'saved_claim_id' => saved_claim_id)
        workflow_batch.jobs do
          SubmitForm526.perform_async(user_uuid, auth_headers, saved_claim_id, submission_data)
        end
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
          response = service(@auth_headers).submit_form526(@submission_data['form526'])
          success_handler(response)
        end
      rescue Common::Exceptions::GatewayTimeout => e
        retryable_error_handler(e)
      rescue StandardError => e
        non_retryable_error_handler(e)
      end

      def complete(status, options)
        puts "COMPLETE!"
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
        transaction_class.update_transaction(jid, :received, response.attributes)

        workflow_batch = Sidekiq::Batch.new(bid)
        workflow_batch.jobs do
          submit_uploads(response.claim_id) if @submission_data['form526_uploads'].present?
          submit_form_4142(response.claim_id) if @submission_data['form4142'].present?
          submit_form_0781(response) if @submission_data['form0781'].present?
          cleanup
        end
      end

      def submit_uploads(claim_id)
        @submission_data['form526_uploads'].each do |upload_data|
          EVSS::DisabilityCompensationForm::SubmitUploads.perform_async(
            @auth_headers, claim_id, @saved_claim_id, @submission_id, upload_data
          )
        end
      end

      def submit_form_4142(claim_id)
        CentralMail::SubmitForm4142Job.perform_async(
          claim_id, @saved_claim_id, @submission_id, @submission_data['form4142']
        )
      end

      def submit_form_0781(response)
        EVSS::DisabilityCompensationForm::SubmitForm0781.perform_async(
          @auth_headers, response.claim_id, @saved_claim_id, @submission_id, @submission_data['form0781']
        )
      end

      def cleanup
        EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(@user_uuid)
      end

      def non_retryable_error_handler(error)
        message = error.try(:messages) || { error: error.message }
        transaction_class.update_transaction(jid, :non_retryable_error, message)
        super(error)
      end

      def retryable_error_handler(error)
        transaction_class.update_transaction(jid, :retrying, error: error.message)
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

      def transaction_class
        AsyncTransaction::EVSS::VA526ezSubmitTransaction
      end

      def submission_rate_limiter
        Common::EventRateLimiter.new(REDIS_CONFIG['evss_526_submit_form_rate_limit'])
      end
    end
  end
end
