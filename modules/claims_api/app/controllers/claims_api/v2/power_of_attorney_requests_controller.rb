# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < PowerOfAttorneyRequests::BaseController
      def index
        index_params =
          params.permit(
            filter: {},
            page: {},
            sort: {}
          ).to_h

        result =
          PowerOfAttorneyRequestService::Search.perform(
            index_params
          )

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
