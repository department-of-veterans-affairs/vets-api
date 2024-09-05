# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  module V0
    module LighthouseClaims
      class ClaimsIndexInterface
        CLAIMS_NOT_AUTHORIZED_MESSAGE = 'Forbidden: User is not authorized for claims'
        APPEALS_NOT_AUTHORIZED_MESSAGE = 'Forbidden: User is not authorized for appeals'

        def initialize(user)
          @current_user = user
        end

        def get_accessible_claims_appeals(use_cache)
          raise Pundit::NotAuthorizedError unless claims_access? || appeals_access?

          data, errors = get_claims_and_appeals(use_cache)
          set_cache(data) unless errors.any?

          errors.push({ service: 'appeals', error_details: APPEALS_NOT_AUTHORIZED_MESSAGE }) unless appeals_access?
          errors.push({ service: 'claims', error_details: CLAIMS_NOT_AUTHORIZED_MESSAGE }) unless claims_access?

          [data, errors]
        end

        private

        def set_cache(data)
          Mobile::V0::ClaimOverview.set_cached(@current_user, data)
        end

        def get_claims_and_appeals(use_cache)
          full_list = []
          errors = []
          data = Mobile::V0::ClaimOverview.get_cached(@current_user) if use_cache

          unless data
            if claims_access? && appeals_access?
              claims, appeals = Parallel.map([service.get_all_claims, service.get_all_appeals], in_threads: 2, &:call)
            elsif claims_access?
              claims = service.get_all_claims.call
            elsif appeals_access?
              appeals = service.get_all_appeals.call
            end

            if claims
              claims[:errors].nil? ? full_list.push(*claims[:list]) : errors.push(claims[:errors])
            end
            if appeals
              appeals[:errors].nil? ? full_list.push(*appeals[:list]) : errors.push(appeals[:errors])
            end

            data = claims_adapter.parse(full_list)
          end

          [data, errors]
        end

        def service
          claim_status_lighthouse? ? lighthouse_claims_proxy : evss_claims_proxy
        end

        def claims_access?
          if claim_status_lighthouse?
            @current_user.authorize(:lighthouse, :access?)
          else
            @current_user.authorize(:evss, :access?)
          end
        end

        def appeals_access?
          @current_user.authorize(:appeals, :access?)
        end

        def claim_status_lighthouse?
          Flipper.enabled?(:mobile_lighthouse_claims, @current_user)
        end

        def lighthouse_claims_proxy
          Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
        end

        def claims_adapter
          if claim_status_lighthouse?
            Mobile::V0::Adapters::LighthouseClaimsOverview.new
          else
            Mobile::V0::Adapters::ClaimsOverview.new
          end
        end

        def evss_claims_proxy
          @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
        end
      end
    end
  end
end
