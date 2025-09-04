# frozen_string_literal: true

module TravelPay
  module V0
    class ComplexClaimsController < ApplicationController
      include AuthHelper

      rescue_from Common::Exceptions::BadRequest, with: :render_bad_request
      rescue_from Common::Exceptions::ServiceUnavailable, with: :render_service_unavailable

      def submit
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay submit complex claim unavailable per feature toggle'
        )

        claim_id = params[:id]
        validate_claim_id_exists!(claim_id)

        # TODO: add validation to verify there is a document associated to a given expense
        # TODO: possibly add validation to verify the claim id is valid
        Rails.logger.info(message: 'Submit complex claim')
        submitted_claim = claims_service.submit_claim(claim_id)

        render json: submitted_claim, status: :created
      rescue ArgumentError => ep
        raise Common::Exceptions::BadRequest.new(detail: e.message)
      rescue Faraday::ClientError, Faraday::ServerError => e
        Rails.logger.error("Faraday error submitting complex claim: #{e.message}")
        raise Common::Exceptions::InternalServerError.new(exception: e)
      end

      private

      def render_bad_request(e)
        # If the error has a list of messages, use those
        errors = if e.respond_to?(:errors) && e.errors.present?
                   e.errors.map do |err|
                     if err.is_a?(Hash)
                       err
                     elsif err.respond_to?(:detail)
                       { detail: err.detail, title: err.try(:title), code: err.try(:code), status: err.try(:status) }
                     else
                       { detail: err.to_s }
                     end
                   end
                 else
                   # If nothing special came through, just send a basic message
                   [{ detail: 'Bad request' }]
                 end
        render json: { errors: }, status: :bad_request
      end

      def render_service_unavailable(e)
        Rails.logger.error("Service unavailable: #{e.message}")
        render json: { error: e.message }, status: :service_unavailable
      end

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager, @current_user)
      end
    end
  end
end
