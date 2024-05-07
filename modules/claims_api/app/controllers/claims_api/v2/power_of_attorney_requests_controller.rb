# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < ApplicationController
      BAD_GATEWAY_ERRORS = [
        BGSClient::Error::BGSFault,
        BGSClient::Error::ConnectionFailed,
        BGSClient::Error::SSLError
      ].freeze

      def index
        result =
          PowerOfAttorneyRequestService::Search.perform(
            search_params.to_h
          )

        result[:data] =
          Blueprints::PowerOfAttorneyRequestBlueprint.render_as_hash(
            result[:data]
          )

        render json: result
      rescue PowerOfAttorneyRequestService::Search::InvalidQueryError => e
        detail = { errors: e.errors, params: e.params }
        raise ::Common::Exceptions::BadRequest, detail:
      rescue *BAD_GATEWAY_ERRORS => e
        raise ::Common::Exceptions::BadGateway, detail: e.message
      rescue BGSClient::Error::TimeoutError
        raise ::Common::Exceptions::GatewayTimeout
      end

      private

      def search_params
        params.permit(filter: {}, page: {}, sort: {})
      end
    end
  end
end
