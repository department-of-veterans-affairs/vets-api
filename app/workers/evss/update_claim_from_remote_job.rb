# frozen_string_literal: true

require 'evss/common_service'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module EVSS
  class UpdateClaimFromRemoteJob
    include Sidekiq::Worker
    sidekiq_options unique_for: 1.hour, retry: 8

    sidekiq_retries_exhausted do |msg, _e|
      Sentry::TagRainbows.tag
      cacher = EVSSClaimsRedisHelper.new(user_uuid: msg['args'][0], claim_id: msg['args'][1])
      cacher.cache_one(status: 'FAILED')
    end

    def perform(user_uuid, claim_id)
      Sentry::TagRainbows.tag
      user = User.find user_uuid
      claim = EVSSClaim.find claim_id
      cacher = EVSSClaimsRedisHelper.new(user_uuid: user_uuid, claim_id: claim_id)
      unless user
        cacher.cache_one(status: 'FAILED_NO_USER')
        return false
      end
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      raw_claim = EVSS::ClaimsService.new(auth_headers).find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim)
      cacher.cache_one(status: 'SUCCESS')
    end
  end
end
