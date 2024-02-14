# frozen_string_literal: true

class EVSS::RequestDecision
  include Sidekiq::Job

  sidekiq_retries_exhausted do |job, ex|
    Sidekiq.logger.warn "Exhausted retries! Failed #{job['class']} with #{job['args']}: #{job['error_message']}"
  end

  def perform(auth_headers, evss_id)
    client = EVSS::ClaimsService.new(auth_headers)
    client.request_decision(evss_id)
  end
end

# Allows gracefully migrating tasks in queue
# TODO(knkski): Remove after migration
class EVSSClaim::RequestDecision
  include Sidekiq::Job

  sidekiq_retries_exhausted do |job, ex|
    Sidekiq.logger.warn "Exhausted retries! Failed #{job['class']} with #{job['args']}: #{job['error_message']}"
  end

  def perform(auth_headers, evss_id)
    EVSS::RequestDecision.perform_async(auth_headers, evss_id)
  end
end
