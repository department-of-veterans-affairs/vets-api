# frozen_string_literal: true

require 'evss/common_service'

module EVSS
  class UpdateClaimFromRemoteJob
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform(user_uuid, claim_id)
      Sentry::TagRainbows.tag
      user = User.find user_uuid
      claim = EVSSClaim.find claim_id
      tracker = EVSSClaimsSyncStatusTracker.find_or_build(user_uuid)
      tracker.claim_id = claim_id
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      raw_claim = EVSS::ClaimsService.new(auth_headers).find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim)
      tracker.set_single_status('SUCCESS')
    rescue StandardError
      tracker.set_single_status('FAILED')
      raise
    end
  end
end
