# frozen_string_literal: true

require 'evss/common_service'

module EVSS
  class RetrieveClaimsFromRemoteJob
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform(user_uuid)
      @user = User.find user_uuid
      tracker = EVSSClaimsSyncStatusTracker.find_or_build(user_uuid)
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
    rescue
      tracker.set_collection_status('FAILED')
      raise
    end

    private

    def create_or_update_claim(raw_claim)
      claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
      claim.update_attributes(list_data: raw_claim)
    end

    def claims_scope
      EVSSClaim.for_user(@user)
    end
  end
end
