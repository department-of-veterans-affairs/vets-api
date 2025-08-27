# frozen_string_literal: true

module TravelPay
  module V0
    class ComplexClaimsController < ApplicationController
      def create
        verify_feature_flag_enabled!
        validate_params_exist!(params)

        appt_id = get_appt!(params)
        claim_id = create_claim(appt_id)
        render json: claim_id, status: :created
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e)
      rescue Faraday::Error => e
        Rails.logger.error("Error downloading document: #{e.message}")
        render json: { error: 'Error downloading document' }, status: e.response[:status]
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Error downloading document: #{e.message}")
        render json: { error: 'Error downloading document' }, status: e.original_status
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager, @current_user)
      end

      def appts_service
        @appts_service ||= TravelPay::AppointmentsService.new(auth_manager)
      end

      def get_appt(params = {})
        Rails.logger.info(message: "Get appt by date time: #{params['appointment_date_time']}")
        appt = appts_service.find_or_create_appointment(params)

        appt[:data]&.dig('id')
      end

      def get_appt!(params = {})
        get_appt(params) ||
          raise(Common::Exceptions::ResourceNotFound,
                detail: "No appointment found for #{params['appointment_date_time']}")
      end

      def create_claim(appt_id)
        Rails.logger.info(message: 'Create complex claim')
        claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

        claim['claimId']
      end

      def validate_params_exist!(params = {})
        {
          'appointment_date_time' => 'Appointment date time is required',
          'facility_station_number' => 'Facility station number is required',
          'appointment_type' => 'Appointment type is required',
          'is_complete' => 'The Is complete field is required'
        }.each do |key, message|
          raise Common::Exceptions::BadRequest.new(detail: message) if params[key].blank?
        end
      end

      def verify_feature_flag_enabled!
        return if Flipper.enabled?(:travel_pay_enable_complex_claims, @current_user)

        message = 'Travel Pay create complex claim unavailable per feature toggle'
        Rails.logger.error(message:)
        raise Common::Exceptions::ServiceUnavailable, message:
      end
    end
  end
end
