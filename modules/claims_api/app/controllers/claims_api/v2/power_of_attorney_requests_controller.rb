# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < PowerOfAttorneyRequests::BaseController
      def index
        result =
          PowerOfAttorneyRequestService::Search.perform(
            request.query_parameters
          )

        result[:metadata].transform_keys! do |key|
          key.to_s.camelize(:lower).to_sym
        end

        result[:data] =
          Blueprints::PowerOfAttorneyRequestBlueprint.render_as_hash(
            result[:data]
          )

        render json: result
      rescue PowerOfAttorneyRequestService::Search::InvalidQueryError => e
        detail = { errors: e.errors, params: e.params }
        error = ::Common::Exceptions::BadRequest.new(detail:)
        render_error(error)
      end
    end
  end
end
