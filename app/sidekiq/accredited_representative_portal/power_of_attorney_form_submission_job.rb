# frozen_string_literal: true

# require 'lighthouse/benefits_claims/service'
require 'sentry_logging'

module AccreditedRepresentativePortal
  class PowerOfAttorneyFormSubmissionJob
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: 2

    attr_reader :response

    def perform(poa_form_submission_id)
      @id = poa_form_submission_id
      service = BenefitsClaims::Service.new(poa_form_submission.power_of_attorney_request.claimant.icn)
      @response = service.get_2122_submission(poa_form_submission.service_id)
      poa_form_submission.update(
        status: (non_error_response? ? :succeeded : :failed),
        service_response: response.to_json,
        status_updated_at: DateTime.current,
        error_message: error_data.to_json
      )
    rescue => e
      handle_errors(e, poa_form_submission)
    end

    sidekiq_retries_exhausted do |job, _ex|
      poa_form_submission_id = job['args'].first
      poa_form_submission = PowerOfAttorneyFormSubmission.find(poa_form_submission_id)
      poa_form_submission.update(status: :failed, status_updated_at: DateTime.current)
    end

    def handle_errors(e, poa_form_submission)
      log_exception_to_sentry(e)
      poa_form_submission.update(error_message: e.message, status: :enqueue_failed)
      raise e
    end

    def non_error_response?
      response.dig('data', 'attributes', 'status') != 'errored'
    end

    def error_data
      response.dig('data', 'attributes', 'errors')
    end

    def poa_form_submission
      @poa_form_submission ||= PowerOfAttorneyFormSubmission.find(@id)
    end
  end
end
