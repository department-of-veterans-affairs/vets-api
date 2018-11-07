# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526 < Job
      TRANSACTION_CLASS = AsyncTransaction::EVSS::VA526ezSubmitTransaction

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 13 will result in a run time of ~25 hours
      RETRY = 7
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        TRANSACTION_CLASS.update_transaction(msg['jid'], :exhausted)
        Rails.logger.error('Form526 Exhausted', 'job_id' => msg['jid'], 'error_message' => msg['error_message'])
        Metrics.new(STATSD_KEY_PREFIX, msg['jid']).increment_exhausted
      end

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param submission_id [Hash] The submission record
      #
      def perform(submission_id)
        super(submission_id)
        with_tracking('Form526 Submission', submission.saved_claim_id, submission.id) do
          service = service(submission.auth_headers)
          response = service.submit_form526(submission.form_to_json(Form526Submission::FORM_526))
          response_handler(response)
        end
      rescue Common::Exceptions::GatewayTimeout => e
        retryable_error_handler(e)
      rescue StandardError => e
        non_retryable_error_handler(e)
      end

      private

      def response_handler(response)
        submission.submitted_claim_id = response.claim_id
        submission.save
        perform_ancillary_jobs
      end

      def perform_ancillary_jobs
        submission.perform_ancillary_jobs(bid)
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
    end
  end
end
