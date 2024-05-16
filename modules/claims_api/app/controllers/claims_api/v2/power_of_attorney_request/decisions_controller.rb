# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequest
      class DecisionsController < BaseController
        def update
          # TODO: Validation where?
          raise "Invalid status: #{decision_params[:status]}" unless declined?

          PowerOfAttorneyRequestService::Decide.perform(
            params[:id],
            decision_params
          )

          head :no_content
        end

        private

        def declined?
          decision_params[:status] ==
            PowerOfAttorneyRequestService::
              PoaRequest::Statuses::
              DECLINED
        end

        def decision_params
          @decision_params ||=
            params.require(:decision).permit(
              :status,
              :declinedReason,
              representative: {}
            ).to_h
        end
      end
    end
  end
end
