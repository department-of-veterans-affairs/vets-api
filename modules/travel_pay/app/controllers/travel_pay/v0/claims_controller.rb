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

      def show
        begin
          token_service.get_tokens(@current_user) => { veis_token:, btsss_token: }
          claim = claims_service.get_claim_by_id(veis_token, btsss_token, params[:id])
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, message: e.message
        end

        if claim.nil?
          raise Common::Exceptions::ResourceNotFound, message: "Claim not found. ID provided: #{params[:id]}"
        end

        render json: claim, status: :ok
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
