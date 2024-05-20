# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  module V0
    module LighthouseClaims
      class Proxy < Mobile::V0::Claims::Proxy
        delegate :get_claim, to: :claims_service

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
      end
    end
  end
end
