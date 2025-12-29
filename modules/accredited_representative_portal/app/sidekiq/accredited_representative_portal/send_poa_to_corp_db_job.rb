module AccreditedRepresentativePortal
  class SendPoaToCorpDbJob
    include Sidekiq::Job
    sidekiq_options retry: 5, queue: :default

    def perform(poa_request_id)
      poa_request = PowerOfAttorneyRequest.find(poa_request_id)

      # Guard: skip if already sent
      return if poa_request.sent_to_corpdb?

      # Attempt to send to CorpDB
      AccreditedRepresentativePortal::SendPoaToCorpDbService.call(poa_request)

      # Mark as sent only after successful send
      poa_request.update!(sent_to_corpdb_at: Time.current)

    rescue ActiveRecord::RecordNotFound => e
      # Non-retryable: record doesn’t exist, just log
      Rails.logger.error(
        "POA request not found",
        poa_request_id: poa_request_id,
        error: e.message
      )
    rescue Faraday::ClientError, Faraday::ServerError => e
      # Retryable network/API errors: log and re-raise so Sidekiq retries
      Rails.logger.error(
        "Failed to send POA to CorpDB (retrying)",
        poa_request_id: poa_request_id,
        error: e.message
      )
      raise
    rescue StandardError => e
      # Unexpected errors: log and re-raise
      Rails.logger.error(
        "Unexpected error sending POA to CorpDB",
        poa_request_id: poa_request_id,
        error: e.message
      )
      raise
    end
  end
end

