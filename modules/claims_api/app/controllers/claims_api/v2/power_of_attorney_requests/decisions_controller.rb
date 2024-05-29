# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      class DecisionsController < BaseController
        before_action :validate_json!, only: :create

        def create
          attrs =
            @body.dig('data', 'attributes').deep_transform_keys do |key|
              key.underscore.to_sym
            end

          PowerOfAttorneyRequestService::Decide.perform(
            params[:id], attrs
          )

          head :no_content
        end
      end
    end
  end
end
