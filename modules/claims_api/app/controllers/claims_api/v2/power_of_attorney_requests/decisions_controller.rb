# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      class DecisionsController < BaseController
        def create
          decision_params =
            params.require(:decision).permit(
              :status,
              :declinedReason,
              representative: {}
            ).to_h

          attrs = decision_params.deep_transform_keys(&:underscore)
          PowerOfAttorneyRequestService::Decide.perform(params[:id], attrs)

          head :no_content
        end
      end
    end
  end
end
