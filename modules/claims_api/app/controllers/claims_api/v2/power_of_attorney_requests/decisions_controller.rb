# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      class DecisionsController < BaseController
        def update
          decision_params =
            params.require(:decision).permit(
              :status,
              :declinedReason,
              representative: {}
            ).to_h

          attrs = decision_params.deep_transform_keys(&:underscore)
          PowerOfAttorneyRequestService::Decide.perform(params[:id], attrs)

          head :no_content
        rescue PowerOfAttorneyRequestService::Decide::InvalidStatusTransitionError => e
          # Rather than `422` given this guidance:
          #   https://opensource.zalando.com/restful-api-guidelines/#status-code-422
          #   https://opensource.zalando.com/restful-api-guidelines/#status-code-400
          error = ::Common::Exceptions::BadRequest.new(detail: e.message)
          render_error(error)
        end
      end
    end
  end
end
