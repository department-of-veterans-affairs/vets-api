# frozen_string_literal: true

class EVSS::RequestDecision
  include Sidekiq::Job
  # retry for  2d 1h 47m 12s
  # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
  sidekiq_options retry: 16

  def perform(auth_headers, evss_id)
    client = EVSS::ClaimsService.new(auth_headers)
    client.request_decision(evss_id)
  end
end

# Allows gracefully migrating tasks in queue
# TODO(knkski): Remove after migration
class EVSSClaim::RequestDecision
  include Sidekiq::Job

  def perform(auth_headers, evss_id)
    EVSS::RequestDecision.perform_async(auth_headers, evss_id)
  end
end
