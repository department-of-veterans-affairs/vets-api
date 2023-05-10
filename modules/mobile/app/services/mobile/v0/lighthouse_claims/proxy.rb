# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  module V0
    module LighthouseClaims
      class Proxy < Mobile::V0::Claims::Proxy
        delegate :get_claim, to: :claims_service

        private

        def claims_adapter
          Mobile::V0::Adapters::LighthouseClaimsOverview.new
        end

        def claims_service
          @claims_service ||= Mobile::V0::LighthouseClaims::Service.new(@user.icn)
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
      end
    end
  end
end
