# frozen_string_literal: true

require 'central_mail/service'
require 'common/exceptions'
require 'evss/disability_compensation_form/metrics'
require 'evss/disability_compensation_form/form4142_processor'

module CentralMail
  class SubmitForm4142Job < EVSS::DisabilityCompensationForm::Job
    STATSD_KEY_PREFIX = 'worker.evss.submit_form4142'

    # Sidekiq has built in exponential back-off functionality for retrys
    # A max retry attempt of 10 will result in a run time of ~8 hours
    # This job is invoked from 526 background job, ICMHS is reliable
    # and hence this value is set at a lower value
    RETRY = 10

    sidekiq_options retry: RETRY

    class CentralMailResponseError < Common::Exceptions::BackendServiceException
    end

    # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.send(
        :error,
        "Failed all retries on Form4142 submit, last error: #{msg['error_message']}"
      )
      EVSS::DisabilityCompensationForm::Metrics.new(STATSD_KEY_PREFIX).increment_exhausted
    end

    # Performs an asynchronous job for submitting a Form 4142 to central mail service
    #
    # @param submission_id [Integer] the {Form526Submission} id
    #
    def perform(submission_id)
      Raven.tags_context(source: '526EZ-all-claims')
      super(submission_id)
      with_tracking('Form4142 Submission', submission.saved_claim_id, submission.id) do
        processor = EVSS::DisabilityCompensationForm::Form4142Processor.new(submission, jid)
        @pdf_path = processor.pdf_path
        response = CentralMail::Service.new.upload(processor.request_body)
        handle_service_exception(response) if response.present? && response.status.between?(201, 600)
      end
    rescue => e
      # Cannot move job straight to dead queue dynamically within an executing job
      # raising error for all the exceptions as sidekiq will then move into dead queue
      # after all retries are exhausted
      retryable_error_handler(e)
      raise e
    ensure
      File.delete(@pdf_path) if @pdf_path.present?
    end

    private

    # Cannot move job straight to dead queue dynamically within an executing job
    # raising error for all the exceptions as sidekiq will then move into dead queue
    # after all retries are exhausted
    def handle_service_exception(response)
      error = create_service_error(nil, self.class, response)
      raise error
    end

    def create_service_error(key, source, response, _error = nil)
      response_values = response_values(key, source, response.status, response.body)
      CentralMailResponseError.new(key, response_values, nil, nil)
    end

    def response_values(key, source, status, detail)
      {
        status:,
        detail:,
        code: key,
        source: source.to_s
      }
    end
  end
end
