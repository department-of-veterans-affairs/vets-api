# frozen_string_literal: true
module EVSS
  module Claims
    class Service < EVSS::Service
      DEFAULT_TIMEOUT = 120

      configuration EVSS::Claims::Configuration

      def all_claims
        perform(:get, 'vbaClaimStatusService/getClaims', nil)
      end

      def find_claim_by_id(claim_id)
        perform(
          :post,
          'vbaClaimStatusService/getClaimDetailById',
          { id: claim_id }.to_json
        )
      end

      def request_decision(claim_id)
        perform_json(
          path: 'vbaClaimStatusService/set5103Waiver',
          body: {
            claimId: claim_id,
            systemName: SYSTEM_NAME
          }
        )
      end
    end
  end
end
