# frozen_string_literal: true

require 'evss/common_service'

module EVSS
  class RetrieveClaimsForUserJob
    include Sidekiq::Worker
    sidekiq_options unique_for: 1.hour, retry: 8

    sidekiq_retries_exhausted do |msg, _e|
      Sentry::TagRainbows.tag
      tracker = EVSSClaimsSyncStatusTracker.new(user_uuid: msg['args'][0])
      tracker.set_collection_status('FAILED')
    end

    def perform(user_uuid)
      Sentry::TagRainbows.tag
      @user = User.find user_uuid
      tracker = EVSSClaimsSyncStatusTracker.new(user_uuid: user_uuid)
      unless @user
        tracker.set_collection_status('FAILED_NO_USER')
        return false
      end
      auth_headers = EVSS::AuthHeaders.new(@user).to_h
      @client = EVSS::ClaimsService.new(auth_headers)
      raw_claims = @client.all_claims.body
      EVSSClaimService::EVSS_CLAIM_KEYS.each_with_object([]) do |key, claim_accum|
        next unless raw_claims[key]
        claim_accum << raw_claims[key].map do |raw_claim|
          create_or_update_claim(raw_claim)
        end
      end
      tracker.set_collection_status('SUCCESS')
    end

    def create_or_update_claim(raw_claim)
      claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
      claim.update_attributes(list_data: raw_claim)
    end

    def claims_scope
      EVSSClaim.for_user(@user)
    end
  end
end
