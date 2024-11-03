# frozen_string_literal: true

require 'dgib/claimant_lookup/service'
require 'dgib/claimant_status/service'
require 'dgib/verification_record/service'
require 'dgib/verify_claimant/service'

module Vye
  module Vye::V1
    class Vye::V1::DgibVerificationsController < Vye::V1::ApplicationController
      def verification_record
        authorize user_info, policy_class: UserInfoPolicy

        Rails.logger.debug 'Calling verification_record'
        response = verification_service.get_verification_record(params[:claimant_id])
        serializer = Vye::ClaimantVerificationSerializer

        # Mocked response, remove when valid data is available.
        response.status = 200
        response.claimant_id = 1
        response.delimiting_date = "2024-11-01"
        response.enrollment_verifications = [
          {
            "verificationMonth": "December 2023",
            "verificationBeginDate": "2024-11-01",
            "verificationEndDate": "2024-11-01",
            "verificationThroughDate": "2024-11-01",
            "createdDate": "2024-11-01",
            "verificationMethod": "",
            "verificationResponse": "Y",
            "facilityName": "string",
            "totalCreditHours": 0,
            "paymentTransmissionDate": "2024-11-01",
            "lastDepositAmount": 0,
            "remainingEntitlement": "53-01"
          }
        ]
        response.payment_on_hold = true
        # Mocked response, remove when valid data is available.

        process_response(response, serializer)
      end

      def verify_claimant
        authorize user_info, policy_class: UserInfoPolicy

        response =
          verify_claimant_service
          .verify_claimant(
            params[:claimant_id],
            params[:verified_period_begin_date],
            params[:verified_period_end_date],
            params[:verfied_through_date]
          )

        serializer = Vye::VerifyClaimantSerializer
        process_response(response, serializer)
      end

      # the serializer for this endpoint is the same as for verify_claimant
      def claimant_status
        authorize user_info, policy_class: UserInfoPolicy

        response = claimant_status_service.get_claimant_status(params[:claimant_id])
        serializer = Vye::VerifyClaimantSerializer
        process_response(response, serializer)
      end

      def claimant_lookup
        authorize user_info, policy_class: UserInfoPolicy

        response = claimant_lookup_service.claimant_lookup(@current_user.ssn)

        # mocked claimant_id, remove when real data is available
        response.claimant_id = 1

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
        Rails.logger.debug { "Processing response with status: #{response.status}" }
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
        else
          Rails.logger.debug 'Sending internal server error'
          head :internal_server_error
        end
      end
      # End Vye Services
    end
  end
end
