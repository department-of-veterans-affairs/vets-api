# frozen_string_literal: true

require_dependency 'claims_api/application_controller'

module ClaimsApi
  module V0
    module Forms
      class DisabilityCompensationController < ApplicationController
        skip_before_action(:authenticate)

        def form_526
          # build internal payload here
          internal_payload = ClaimsApi::Form526.new(form_attributes).to_internal

          # not sure if auth headers will pass in through job, or store on model
          auth = auth_headers

          # This model id will come from the model that stores the claim submission status
          model_id = nil
          ClaimsApi::ClaimEstablisher.perform(model_id)

          # This will likely be a serialized version of the model
          render {}.to_json
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
          ClaimsApi::Veteran.new(
            ssn: ssn,
            loa: { current: :loa3 },
            first_name: first_name,
            last_name: last_name,
            va_profile: va_profile,
            edipi: edipi,
            last_signed_in: Time.zone.now
          )
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
