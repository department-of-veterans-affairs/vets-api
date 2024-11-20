# frozen_string_literal: true

require 'dgib/claimant_lookup/service'
require 'dgib/claimant_status/service'
require 'dgib/verification_record/service'
require 'dgib/verify_claimant/service'

module Vye
  module Vye::V1
    class Vye::V1::DgibVerificationsController < Vye::V1::ApplicationController
      before_action { authorize :vye, :access? }

      def verification_record
        head :forbidden unless authorize(user_info, policy_class: UserInfoPolicy)

        response = verification_service.get_verification_record(params[:claimant_id])
        serializer = Vye::ClaimantVerificationSerializer
        process_response(response, serializer)
      end

      def verify_claimant
        head :forbidden unless authorize(user_info, policy_class: UserInfoPolicy)

        response = verify_claimant_service.verify_claimant(
          params[:claimant_id],
          params[:verified_period_begin_date],
          params[:verified_period_end_date],
          params[:verified_through_date],
          params[:verification_method],
          params.dig(:app_communication, :response_type)
        )

        serializer = Vye::VerifyClaimantSerializer
        process_response(response, serializer)
      end

      # the serializer for this endpoint is the same as for verify_claimant
      def claimant_status
        head :forbidden unless authorize(user_info, policy_class: UserInfoPolicy)

        response = claimant_status_service.get_claimant_status(params[:claimant_id])
        serializer = Vye::VerifyClaimantSerializer
        process_response(response, serializer)
      end

      def claimant_lookup
        head :forbidden unless authorize(user_info, policy_class: UserInfoPolicy)

        response = claimant_lookup_service.claimant_lookup(current_user.ssn)
        serializer = Vye::ClaimantLookupSerializer
        process_response(response, serializer)
      end

      private

      # Vye Services related stuff
      def claimant_lookup_service
        Vye::DGIB::ClaimantLookup::Service.new(@current_user)
      end

      def claimant_status_service
        Vye::DGIB::ClaimantStatus::Service.new(@current_user)
      end

      def verification_service
        Vye::DGIB::VerificationRecord::Service.new(@current_user)
      end

      def verify_claimant_service
        Vye::DGIB::VerifyClaimant::Service.new(@current_user)
      end

      def process_response(response, serializer)
        Rails.logger.debug { "Processing response with status: #{response&.status}" }
        case response.status
        when 200
          Rails.logger.debug 'Rendering JSON response'
          render json: serializer.new(response).to_json
        when 204
          Rails.logger.debug 'Sending no content'
          head :no_content
        when 403
          Rails.logger.debug 'Sending forbidden'
          head :forbidden
        when 404
          Rails.logger.debug 'Sending not found'
          head :not_found
        when 422
          Rails.logger.debug 'Sending unprocessable entity'
          head :unprocessable_entity
        when nil
          Rails.logger.debug 'No response from server'
        else
          Rails.logger.debug 'Sending internal server error'
          head :internal_server_error
        end
      end
      # End Vye Services
    end
  end
end
