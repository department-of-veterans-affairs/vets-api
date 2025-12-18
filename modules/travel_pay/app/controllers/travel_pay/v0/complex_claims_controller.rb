# frozen_string_literal: true

module TravelPay
  module V0
    class ComplexClaimsController < ApplicationController
      include FeatureFlagHelper
      include AppointmentHelper
      include ClaimHelper
      include IdValidation

      def version_map
        should_upgrade = Flipper.enabled?(:travel_pay_claims_api_v3_upgrade)
        {
          get_claims: should_upgrade ? 'v3' : 'v2',
          get_claim_by_id: should_upgrade ? 'v3' : 'v2',
          get_claims_by_date: should_upgrade ? 'v3' : 'v2',
          create_claim: should_upgrade ? 'v3' : 'v2',
          submit_claim: should_upgrade ? 'v3' : 'v2'
        }
      end

      rescue_from Common::Exceptions::BadRequest, with: :render_bad_request

      before_action :check_feature_flag

      def submit
        claim_id = params[:claim_id]
        validate_uuid_exists!(claim_id, 'Claim')

        # TODO: add validation to verify there is a document associated to a given expense
        # TODO: possibly add validation to verify the claim id is valid
        Rails.logger.info(message: 'Submit complex claim')
        submitted_claim = claims_service.submit_claim(claim_id)

        render json: submitted_claim, status: :created
      rescue Faraday::ClientError => e
        # 400-level errors (bad request, unauthorized, forbidden)
        handle_faraday_error(e, 'Invalid request for complex claim', log_prefix: 'Submitting complex claim: ')
      rescue Faraday::ServerError => e
        # 500-level errors
        handle_faraday_error(e, 'Server error submitting complex claim', log_prefix: 'Submitting complex claim: ')
      rescue Faraday::Error => e
        # Catch all for Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError
        handle_faraday_error(e, 'Error creating complex claim', log_prefix: 'Submitting complex claim: ')
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

      # Handles Faraday errors for both client (4xx) and server (5xx)
      # e: the Faraday error
      # default_message: fallback message if response body is missing
      # log_prefix: optional prefix for log message
      def handle_faraday_error(e, default_message, log_prefix: '')
        error_type = e.is_a?(Faraday::ClientError) ? 'client' : 'server'
        Rails.logger.error("#{log_prefix}Faraday #{error_type} error: #{e.message}")

        http_status = e.response&.dig(:status) ||
                      (e.is_a?(Faraday::ClientError) ? :bad_request : :internal_server_error)
        message = if e.response&.dig(:body).present?
                    e.response[:body]
                  else
                    default_message
                  end

        render json: { errors: [{ detail: message }] }, status: http_status
      end

      def check_feature_flag
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay complex claim endpoint unavailable per feature toggle'
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
