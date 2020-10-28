# frozen_string_literal: true

require 'evss/disability_compensation_form/service_exception'
require 'evss/disability_compensation_form/gateway_timeout'

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
        job_exhausted(msg, STATSD_KEY_PREFIX)
      end
      # :nocov:

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        super(submission_id)
        with_tracking('Form526 Submission', submission.saved_claim_id, submission.id, submission.bdd?) do
          service = service(submission.auth_headers)
          response = service.submit_form526(submission.form_to_json(Form526Submission::FORM_526))
          response_handler(response)
        end
      rescue Common::Exceptions::GatewayTimeout, Breakers::OutageException => e
        retryable_error_handler(e)
      rescue EVSS::DisabilityCompensationForm::ServiceException => e
        # retry submitting the form for specific upstream errors
        retry_form526_error_handler!(e)
      rescue => e
        non_retryable_error_handler(e)
      end

      private

      def response_handler(response)
        submission.submitted_claim_id = response.claim_id
        submission.save
      end

      def retryable_error_handler(error)
        # update JobStatus, log and metrics in JobStatus#retryable_error_handler
        super(error)
        raise error
      end

      def service(_auth_headers)
        raise NotImplementedError, 'Subclass of SubmitForm526 must implement #service'
      end

      # Logic for retrying a job due to an upstream service error.
      # Retry if any upstream external service unavailability exceptions (unless it is caused by an invalid EP code)
      # and any PIF-in-use exceptions are encountered.
      # Otherwise the job is marked as non-retryable and completed.
      #
      # @param error [EVSS::DisabilityCompensationForm::ServiceException]
      #
      def retry_form526_error_handler!(error)
        if error.retryable?
          retryable_error_handler(error)
        else
          non_retryable_error_handler(error)
        end
      end
    end
  end
end
