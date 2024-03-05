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
          claims_service.submit5103(@user, id)
        end

        def get_all_claims
          lambda {
            begin
              claims_list = claims_service.get_claims
              {
                list: claims_list['data'],
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
      end
    end
  end
end
