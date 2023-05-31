# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  module V0
    module LighthouseClaims
      class Proxy < Mobile::V0::Claims::Proxy
        delegate :get_claim, to: :claims_service

        def get_claims_and_appeals
          claims = get_all_claims
          appeals = get_all_appeals

          full_list = []
          errors = []

          claims[:errors].nil? ? full_list.push(*claims[:list]) : errors.push(claims[:errors])
          appeals[:errors].nil? ? full_list.push(*appeals[:list]) : errors.push(appeals[:errors])
          data = claims_adapter.parse(full_list)

          [data, errors]
        end

        private

        def claims_adapter
          Mobile::V0::Adapters::LighthouseClaimsOverview.new
        end

        def claims_service
          @claims_service ||= BenefitsClaims::Service.new(@user.icn)
        end

        def get_all_claims
          claims_list = claims_service.get_claims
          {
            list: claims_list['data'],
            errors: nil
          }
        rescue => e
          { list: nil, errors: Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'claims') }
        end

        def get_all_appeals
          { list: appeals_service.get_appeals(@user).body['data'], errors: nil }
        rescue => e
          { list: nil, errors: Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'appeals') }
        end
      end
    end
  end
end
