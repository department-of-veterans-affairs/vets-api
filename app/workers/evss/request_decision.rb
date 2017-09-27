# frozen_string_literal: true
class EVSS::RequestDecision
  include Sidekiq::Worker

  def perform(user_uuid, evss_id)
    client = EVSS::Claims::Service.new(User.find(user_uuid))
    client.request_decision(evss_id)
  end
end
