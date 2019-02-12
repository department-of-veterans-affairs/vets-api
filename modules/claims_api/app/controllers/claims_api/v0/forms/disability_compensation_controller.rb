# frozen_string_literal: true

require_dependency 'claims_api/application_controller'

module ClaimsApi
  module V0
    module Forms
      class DisabilityCompensationController < ApplicationController
        skip_before_action(:authenticate)

        def form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers_encrypted: auth_headers,
            form_data_encrypted: form_attributes
          )

          ClaimsApi::ClaimEstablisher.perform(auto_claim.id)

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        def form_4142; end

        def form_0781; end

        def form_8940; end

        private

        def form_attributes
          params[:data][:attributes]
        end

        # This was copy pasta from claims_controller. lets abstract better
        # Also it's very broken and references other functions, I just didn't
        # want to muddy the waters
        def target_veteran
          ClaimsApi::Veteran.from_headers(request.headers, true)
        end

        def auth_headers
          EVSS::DisabilityCompensationAuthHeaders
            .new(target_veteran)
            .add_headers(
              EVSS::AuthHeaders.new(target_veteran).to_h
            )
        end
      end
    end
  end
end
