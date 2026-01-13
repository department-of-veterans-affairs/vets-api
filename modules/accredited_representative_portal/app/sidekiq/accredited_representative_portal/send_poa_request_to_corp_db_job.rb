# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SendPoaRequestToCorpDbJob
    include Sidekiq::Job

    sidekiq_options retry: 5, queue: :default

    # Called when all retries are exhausted and the job is about to be
    # moved to the Dead set.
    #
    # NOTE: Durable failure tracking and automated resubmission require
    # database-backed state and will be implemented in a follow-up PR
    # per strong migrations guidelines.
    sidekiq_retries_exhausted do |job, exception|
      poa_request_id = job['args'].first

      Rails.logger.error(
        'SendPoaRequestToCorpDbJob retries exhausted',
        poa_request_id:,
        job_id: job['jid'],
        error_class: exception.class.name,
        error_message: exception.message
      )
    end

    def perform(poa_request_id)
      poa_request = find_poa_request(poa_request_id)

      send_to_corpdb(poa_request)
    rescue ActiveRecord::RecordNotFound => e
      # Non-retryable: the record no longer exists
      log_non_retryable_error(poa_request_id, e)
    rescue Faraday::ClientError, Faraday::ServerError => e
      # Retryable: transient external failure
      log_retryable_error(poa_request_id, e)
      raise
    rescue => e
      # Unexpected failure: allow Sidekiq to retry and eventually exhaust
      log_unexpected_error(poa_request_id, e)
      raise
    end

    private

    def find_poa_request(poa_request_id)
      PowerOfAttorneyRequest.find(poa_request_id)
    end

    def send_to_corpdb(poa_request)
      AccreditedRepresentativePortal::SendPoaRequestToCorpDbService.call(poa_request)
    end

    def log_non_retryable_error(poa_request_id, error)
      Rails.logger.error(
        'POA Request not found',
        poa_request_id:,
        error_class: error.class.name,
        message: error.message
      )
    end

    def log_retryable_error(poa_request_id, error)
      Rails.logger.error(
        'Failed to send POA Request to CorpDB (retrying)',
        poa_request_id:,
        error_class: error.class.name,
        message: error.message
      )
    end

    def log_unexpected_error(poa_request_id, error)
      Rails.logger.error(
        'Unexpected error sending POA Request to CorpDB',
        poa_request_id:,
        error_class: error.class.name,
        message: error.message
      )
    end
  end
end
