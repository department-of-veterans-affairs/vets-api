# frozen_string_literal: true

class EVSS::RequestDecision
  include Sidekiq::Job

  # retry for one day
  sidekiq_options retry: 14, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
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

  # retry for one day
  sidekiq_options retry: 14, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  def perform(auth_headers, evss_id)
    EVSS::RequestDecision.perform_async(auth_headers, evss_id)
  end
end
