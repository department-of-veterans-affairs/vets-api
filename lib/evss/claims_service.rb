# frozen_string_literal: true
require_dependency 'evss/base_service'

module EVSS
  class ClaimsService < BaseService
    def claims
      get 'vbaClaimStatusService/getOpenClaims'
    end

    def find_claim_by_id(claim_id)
      post 'vbaClaimStatusService/getClaimDetailById', { id: claim_id }.to_json
    end

    def create_intent_to_file
      post 'claimServicesExternalService/listAllIntentToFile', {}.to_json
    end

    def submit_5103_waiver(claim_id)
      post 'vbaClaimStatusService/set5103Waiver', {
        claimId: claim_id,
        systemName: SYSTEM_NAME
      }.to_json
    end

    protected

    def base_url
      ENV['EVSS_CLAIMS_BASE_URL']
    end
  end
end
