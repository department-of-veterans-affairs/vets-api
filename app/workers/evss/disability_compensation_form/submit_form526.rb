# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526 < Job
      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 13 will result in a run time of ~25 hours
      RETRY = 13
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        job_exhausted(msg)
      end
      # :nocov:

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param submission_id [Integer] The {Form526Submission} id
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
      end

      def retryable_error_handler(error)
        super(error)
        raise EVSS::DisabilityCompensationForm::GatewayTimeout, error.message
      end

      def service(_auth_headers)
        raise NotImplementedError, 'Subclass of SubmitForm526 must implement #service'
      end
    end
  end
end
