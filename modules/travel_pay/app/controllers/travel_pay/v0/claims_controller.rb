# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      def index
        begin
          tokens = token_service.get_tokens(@current_user)
          claims = claims_service.get_claims(tokens['veis_token'], tokens['btsss_token'])
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        end

        render json: claims, status: :ok
      end

      private

      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new
      end

      def token_service
        @token_service ||= TravelPay::TokenService.new
      end

      def common_exception(e)
        case e
        when Faraday::ResourceNotFound
          Common::Exceptions::ResourceNotFound.new
        else
          Common::Exceptions::InternalServerError.new
        end
      end
    end
  end
end
