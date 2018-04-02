# frozen_string_literal: true

class EVSS::RequestDecision
  include Sidekiq::Worker

  def perform(auth_headers, evss_id)
    Sentry::TagRainbows.tag
    client = EVSS::ClaimsService.new(auth_headers)
    client.request_decision(evss_id)
  end
end
