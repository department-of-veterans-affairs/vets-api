# frozen_string_literal: true
class DisabilityClaim::RequestDecision
  include Sidekiq::Worker

  def perform(auth_headers, evss_id)
    client = EVSS::ClaimsService.new(auth_headers)
    client.submit_5103_waiver(evss_id)
  end
end
