# frozen_string_literal: true

require 'vye/dgib/service'

module Vye
  module V1
    class DgibVerificationsController < ::ApplicationController
      service_tag 'verify-your-enrollment'
      rescue_from Pundit::NotAuthorizedError, with: -> { render json: { error: 'Forbidden' }, status: :forbidden }

      after_action :verify_authorized

      before_action { authorize :vye, :access? }

      def verification_record
        response = service.get_verification_record(params[:claimant_id])
        serializer = ClaimantVerificationSerializer
        process_response(response, serializer)
      end

      def verify_claimant
        response = service.verify_claimant(
          params[:claimant_id],
          params[:verified_period_begin_date],
          params[:verified_period_end_date],
          params[:verified_through_date],
          params[:verification_method],
          params.dig(:app_communication, :response_type)
        )

        serializer = VerifyClaimantSerializer
        process_response(response, serializer)
      end

      # the serializer for this endpoint is the same as for verify_claimant
      def claimant_status
        response = service.get_claimant_status(params[:claimant_id])
        serializer = VerifyClaimantSerializer
        process_response(response, serializer)
      end

      def claimant_lookup
        response = service.claimant_lookup(current_user.ssn)
        serializer = ClaimantLookupSerializer
        process_response(response, serializer)
      end

      private

      # Vye Services related stuff
      def service
        Vye::DGIB::Service.new(@current_user)
      end

      def process_response(response, serializer)
        case response.status
        when 200
          render json: serializer.new(response).to_json
        when 204
          head :no_content
        when 403
          head :forbidden
        when 404
          head :not_found
        when 422
          head :unprocessable_entity
        when nil
          Rails.logger.error "#{self.class.name}##{__method__} - Nil response status - possible network/client error"
          head :service_unavailable
        else
          Rails.logger.error "#{self.class.name}##{__method__} - Unexpected response status: #{response&.status}"
          head :internal_server_error
        end
      end
      # End Vye Services
    end
  end
end
