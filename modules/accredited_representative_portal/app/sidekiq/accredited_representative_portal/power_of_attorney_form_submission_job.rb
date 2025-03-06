# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyFormSubmissionJob
    class PendingSubmissionError < StandardError; end

    include Sidekiq::Job

    ##
    # This retry duration follows the retry duration used by Lighthouse to
    # accommodate BGS's regular planned maintenance windows of 24 hours.
    #
    # It turns out that Lighthouse's background POA submissions uses the same
    # backoff logic from `Sidekiq` as we do. This means that our status checking
    # will likely pathologically slightly outrace theirs, making us wait until
    # the next poll for an update.
    #
    sidekiq_options retry_for: 48.hours

    attr_reader :response

    def perform(poa_form_submission_id)
      @id = poa_form_submission_id
      service = BenefitsClaims::Service.new(poa_form_submission.power_of_attorney_request.claimant.icn)
      @response = service.get_2122_submission(poa_form_submission.service_id)
      poa_form_submission.update(
        status: new_status,
        service_response: response.to_json,
        status_updated_at: DateTime.current,
        error_message: error_data.to_json
      )
      raise PendingSubmissionError, '2122 still pending' if new_status == :enqueue_succeeded
    rescue => e
      handle_errors(e, poa_form_submission)
    end

    sidekiq_retries_exhausted do |job, _ex|
      poa_form_submission_id = job['args'].first
      poa_form_submission = PowerOfAttorneyFormSubmission.find(poa_form_submission_id)
      poa_form_submission.update(status: :failed, status_updated_at: DateTime.current)
    end

    def handle_errors(e, poa_form_submission)
      poa_form_submission.update(error_message: e.message)
      raise e
    end

    def response_status
      @response_status ||= response.dig('data', 'attributes', 'status')
    end

    def new_status
      case response_status
      when 'updated'
        :succeeded
      when 'errored'
        :failed
      else
        :enqueue_succeeded
      end
    end

    def error_data
      response.dig('data', 'attributes', 'errors')
    end

    def poa_form_submission
      @poa_form_submission ||= PowerOfAttorneyFormSubmission.find(@id)
    end
  end
end
