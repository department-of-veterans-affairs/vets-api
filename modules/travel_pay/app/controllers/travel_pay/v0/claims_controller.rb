# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      def index
        begin
          token_service.get_tokens(@current_user) => { veis_token:, btsss_token: }
          claims = claims_service.get_claims(veis_token, btsss_token, params)
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
    end
  end
end
