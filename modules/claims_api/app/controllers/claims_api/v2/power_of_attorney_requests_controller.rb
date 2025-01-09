# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < PowerOfAttorneyRequests::BaseController
      def index
        service = PowerOfAttorneyRequestService::Search
        result = service.perform(request.query_parameters)

        render json: serialize(result)
      end

      private

      def serialize(result)
        blueprint = Blueprints::PowerOfAttorneyRequestBlueprint
        result[:data] = blueprint.render_as_hash(result[:data])

        result[:metadata].transform_keys! do |key|
          key.to_s.camelize(:lower).to_sym
        end

        result
      end
    end
  end
end