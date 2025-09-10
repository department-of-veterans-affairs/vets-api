# frozen_string_literal: true

module TravelPay
  module V0
    class ComplexClaimsController < ApplicationController
      include FeatureFlagHelper
      include AppointmentHelper
      include ClaimHelper

      rescue_from Common::Exceptions::BadRequest, with: :render_bad_request
      rescue_from Common::Exceptions::ServiceUnavailable, with: :render_service_unavailable

      before_action :check_feature_flag

      def submit
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay submit complex claim unavailable per feature toggle'
        )

        claim_id = params[:claim_id]
        validate_claim_id_exists!(claim_id)

        # TODO: add validation to verify there is a document associated to a given expense
        # TODO: possibly add validation to verify the claim id is valid
        Rails.logger.info(message: 'Submit complex claim')
        submitted_claim = claims_service.submit_claim(claim_id)

        render json: submitted_claim, status: :created
      rescue Faraday::ClientError => e
        Rails.logger.error("Faraday client error submitting complex claim: #{e.message}")
        # TODO: Adjust this once API team confirms expected status codes
        raise Common::Exceptions::BadRequest.new(detail: 'Invalid request for complex claim')
      rescue Faraday::ServerError => e
        Rails.logger.error("Faraday server error submitting complex claim: #{e.message}")
        raise Common::Exceptions::InternalServerError.new(exception: e)
      end

      def create
        params.require(%i[appointment_date_time facility_station_number appointment_type is_complete])
        validate_datetime_format!(params[:appointment_date_time])
        appt_id = find_or_create_appt_id!('Complex', params)
        claim_id = create_claim(appt_id, 'Complex')
        render json: { claimId: claim_id }, status: :created
      rescue Common::Exceptions::ResourceNotFound => e
        Rails.logger.error("Appointment not found: #{e.message}")
        render json: { error: e.message }, status: :not_found
      rescue Faraday::Error => e
        Rails.logger.error("Faraday error creating complex claim: #{e.message}")
        # Some Faraday errors may not have a response object (e.response can be nil),
        # so we fall back to :internal_server_error
        status_code = (e.respond_to?(:response) && e.response && e.response[:status]) || :internal_server_error
        render json: { error: 'Error creating complex claim' }, status: status_code
      end

      private

      def check_feature_flag
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay create complex claim unavailable per feature toggle'
        )
      end

      def render_bad_request(e)
        # Extract the first detail from errors array, fallback to generic
        error_detail = if e.respond_to?(:errors) && e.errors.any?
                         e.errors.first[:detail] || 'Bad request'
                       else
                         'Bad request'
                       end

        render json: { errors: [{ detail: error_detail }] }, status: :bad_request
      end

      def render_service_unavailable(e)
        Rails.logger.error("Service unavailable: #{e.message}")
        render json: { error: e.message }, status: :service_unavailable
      end

      def validate_datetime_format!(datetime_str)
        DateTime.iso8601(datetime_str)
      rescue ArgumentError
        raise Common::Exceptions::BadRequest.new(
          detail: 'Appointment date time must be a valid datetime'
        )
      end
    end
  end
end
