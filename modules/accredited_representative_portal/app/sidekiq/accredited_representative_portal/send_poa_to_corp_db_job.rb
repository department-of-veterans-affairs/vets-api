# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SendPoaToCorpDbJob
    include Sidekiq::Job
    sidekiq_options retry: 5, queue: :default

    def perform(poa_request_id)
      poa_request = find_poa_request(poa_request_id)

      # Attempt to send to CorpDB
      send_to_corpdb(poa_request)
    rescue ActiveRecord::RecordNotFound => e
      log_non_retryable_error(poa_request_id, e)
    rescue Faraday::ClientError, Faraday::ServerError => e
      log_retryable_error(poa_request_id, e)
      raise
    rescue => e
      log_unexpected_error(poa_request_id, e)
      raise
    end

    private

    def find_poa_request(poa_request_id)
      PowerOfAttorneyRequest.find(poa_request_id)
    end

    def send_to_corpdb(poa_request)
      AccreditedRepresentativePortal::SendPoaToCorpDbService.call(poa_request)
    end

    def log_non_retryable_error(poa_request_id, error)
      Rails.logger.error(
        'POA request not found',
        poa_request_id:,
        error: error.message
      )
    end

    def log_retryable_error(poa_request_id, error)
      Rails.logger.error(
        'Failed to send POA to CorpDB (retrying)',
        poa_request_id:,
        error: error.message
      )
    end

    def log_unexpected_error(poa_request_id, error)
      Rails.logger.error(
        'Unexpected error sending POA to CorpDB',
        poa_request_id:,
        error: error.message
      )
    end
  end
end
