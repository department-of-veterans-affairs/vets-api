# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module Claims
    class Service < EVSS::Service
      configuration EVSS::Claims::Configuration

      def initialize(current_user)
        @current_user = current_user
      end

      def all_claims
        perform(:get, 'vbaClaimStatusService/getClaims', nil, headers_for_user(@current_user))
      end

      def find_claim_by_id(claim_id)
        post 'vbaClaimStatusService/getClaimDetailById', { id: claim_id }.to_json
      end

      def request_decision(claim_id)
        post 'vbaClaimStatusService/set5103Waiver', {
          claimId: claim_id,
          systemName: SYSTEM_NAME
        }.to_json
      end
    end
  end
end
