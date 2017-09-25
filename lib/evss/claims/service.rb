# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module Claims
    class Service < EVSS::Service
      SYSTEM_NAME = 'vets.gov'

      configuration EVSS::Claims::Configuration

      def initialize(current_user)
        @current_user = current_user
      end

      def all_claims
        perform(:get, 'vbaClaimStatusService/getClaims', nil, headers_for_user(@current_user))
      end

      def find_claim_by_id(claim_id)
        perform(
          :post,
          'vbaClaimStatusService/getClaimDetailById',
          { id: claim_id }.to_json,
          headers_for_user(@current_user)
        )
      end

      def request_decision(claim_id)
        perform(
          :post,
          'vbaClaimStatusService/set5103Waiver',
          {
            claimId: claim_id,
            systemName: SYSTEM_NAME
          }.to_json,
          headers_for_user(@current_user)
        )
      end
    end
  end
end
