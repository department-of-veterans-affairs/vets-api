# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module V0
  module LighthouseClaims
    # Web-specific proxy for Lighthouse Benefits Claims
    #
    # This proxy wraps the Lighthouse provider and applies web-specific transforms
    # to fix upstream data issues. These transforms are specific to Lighthouse/BGS
    # and should NOT be applied to other providers.
    #
    # Transforms applied:
    # - rename_rv1: Manual status override for RV1 tracked items
    # - suppress_evidence_requests: Filters certain evidence requests (feature-flagged)
    #
    # This pattern ensures future providers don't inherit Lighthouse-specific workarounds.
    class Proxy
      def initialize(user)
        @user = user
        @provider = BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider.new(user)
      end

      delegate :get_claims, to: :@provider

      def get_claim(id)
        claim = @provider.get_claim(id)
        apply_web_transforms(claim)
      end

      private

      def apply_web_transforms(claim)
        claim = rename_rv1(claim)
        claim = suppress_evidence_requests(claim) if Flipper.enabled?(:cst_suppress_evidence_requests_website)
        claim
      end

      # Manual status override for certain tracked items
      # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/101447
      # This should be removed when the items are re-categorized by BGS
      # We are not doing this in the Lighthouse service because we want web and mobile to have
      # separate rollouts and testing.
      def rename_rv1(claim)
        tracked_items = claim.dig('data', 'attributes', 'trackedItems')
        tracked_items&.select { |i| i['displayName'] == 'RV1 - Reserve Records Request' }&.each do |i|
          i['status'] = 'NEEDED_FROM_OTHERS'
        end
        claim
      end

      # https://github.com/department-of-veterans-affairs/va.gov-team/issues/98364
      # This should be removed when the items are removed by BGS
      def suppress_evidence_requests(claim)
        tracked_items = claim.dig('data', 'attributes', 'trackedItems')
        return claim unless tracked_items

        tracked_items.reject! { |i| BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS.include?(i['displayName']) }
        claim
      end
    end
  end
end
