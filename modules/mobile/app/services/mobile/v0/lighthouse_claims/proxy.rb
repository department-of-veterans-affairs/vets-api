# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  module V0
    module LighthouseClaims
      class Proxy < Mobile::V0::Claims::Proxy
        def request_decision(id)
          claims_service.submit5103(id)
        end

        # Temporary: We're adding the claims to the EVSSClaim table until decision letters switch over to lighthouse
        def get_all_claims
          lambda {
            begin
              claims_list = claims_service.get_claims['data']
              claims_list.each { |claim| create_or_update_claim(claim) }
              {
                list: claims_list,
                errors: nil
              }
            rescue => e
              { list: nil, errors: Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'claims') }
            end
          }
        end

        # Manual status override for certain tracked items
        # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/101447
        # This should be removed when the items are re-categorized by BGS
        # We are not doing this in the Lighthouse service because we want web and mobile to have
        # separate rollouts and testing.
        def get_claim(id)
          claim = claims_service.get_claim(id)
          claim = override_rv1(claim) if Flipper.enabled?(:cst_override_reserve_records_mobile)
          # https://github.com/department-of-veterans-affairs/va.gov-team/issues/98364
          # This should be removed when the items are removed by BGS
          claim = suppress_evidence_requests(claim) if Flipper.enabled?(:cst_suppress_evidence_requests_mobile)
          claim
        end

        private

        def claims_service
          @claims_service ||= BenefitsClaims::Service.new(@user.icn)
        end

        def claims_scope
          @claims_scope ||= EVSSClaim.for_user(@user)
        end

        def create_or_update_claim(raw_claim)
          claim = claims_scope.where(evss_id: raw_claim['id']).first
          if claim.blank?
            claim = EVSSClaim.new(user_uuid: @user.uuid,
                                  user_account: @user.user_account,
                                  evss_id: raw_claim['id'],
                                  data: {})
          end
          claim.update(list_data: raw_claim)
        end

        def override_rv1(claim)
          tracked_items = claim.dig('data', 'attributes', 'trackedItems')
          return claim unless tracked_items

          tracked_items.select { |i| i['displayName'] == 'RV1 - Reserve Records Request' }.each do |i|
            i['status'] = 'NEEDED_FROM_OTHERS'
          end
          claim
        end

        def suppress_evidence_requests(claim)
          tracked_items = claim.dig('data', 'attributes', 'trackedItems')
          return unless tracked_items

          tracked_items.reject! { |i| BenefitsClaims::Service::SUPPRESSED_EVIDENCE_REQUESTS.include?(i['displayName']) }
          claim
        end
      end
    end
  end
end
