# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      class DecisionsController < BaseController
        before_action :validate_json!, only: :create

        def create
          PowerOfAttorneyRequestService::Decide.perform(
            params[:power_of_attorney_request_id],
            deserialize(@body)
          )

          render json: {}, status: :accepted
        end

        private

        def deserialize(body)
          body = body.dig('data', 'attributes')
          body.deep_transform_keys do |key|
            key.underscore.to_sym
          end
        end
      end
    end
  end
end
