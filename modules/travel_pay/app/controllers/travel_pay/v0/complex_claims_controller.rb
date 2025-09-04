# frozen_string_literal: true

module TravelPay
  module V0
    class ComplexClaimsController < ApplicationController
      include AuthHelper

      rescue_from Common::Exceptions::BadRequest, with: :render_bad_request
      rescue_from Common::Exceptions::ServiceUnavailable, with: :render_service_unavailable

      def create
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay create complex claim unavailable per feature toggle'
        )
        validate_params_exist!(params)
        validate_datetime_format!(params[:appointment_date_time])
        appt_id = get_appt!(params)
        claim_id = create_claim(appt_id)
        render json: { claimId: claim_id }, status: :created
      rescue Common::Exceptions::ResourceNotFound => e
        Rails.logger.error("Appointment not found: #{e.message}")
        render json: { error: e.message }, status: :not_found
      rescue Faraday::Error => e
        Rails.logger.error("Faraday error creating complex claim: #{e.message}")
        status_code = (e.respond_to?(:response) && e.response && e.response[:status]) || :internal_server_error
        render json: { error: 'Error creating complex claim' }, status: status_code
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Backend service error creating complex claim: #{e.message}")
        render json: { error: 'Error creating complex claim' }, status: e.original_status
      end

      def submit
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay submit complex claim unavailable per feature toggle'
        )

        claim_id = params[:id]
        validate_claim_id_exists!(claim_id)

        # TODO add validation to verify there is a document associated to a given expense
        # TODO possibly add validation to verify the claim id is valid
        Rails.logger.info(message: 'Submit complex claim')
        submitted_claim = claims_service.submit_claim(claim_id)

        render json: submitted_claim, status: :created
      rescue ArgumentError => e
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

      def validate_params_exist!(params = {})
        required_fields = {
          'appointment_date_time' => 'Appointment date time is required',
          'facility_station_number' => 'Facility station number is required',
          'appointment_type' => 'Appointment type is required',
          'is_complete' => 'The Is complete field is required'
        }

        errors = required_fields.each_with_object([]) do |(key, message), arr|
          value = params[key]
          missing = key == 'is_complete' ? value.nil? : value.blank?
          arr << { 'detail' => message } if missing
        end

        # raise only if there are missing fields
        raise Common::Exceptions::BadRequest.new(errors:) unless errors.empty?
      end

      def validate_datetime_format!(datetime_str)
        DateTime.iso8601(datetime_str)
      rescue ArgumentError
        raise Common::Exceptions::BadRequest.new(
          errors: [{ 'detail' => 'Appointment date time must be a valid datetime' }]
        )
      end

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

        return nil if appt.nil? || appt[:data].nil?

        appt[:data]['id']
      end

      def get_appt!(params = {})
        get_appt(params) ||
          raise(
            Common::Exceptions::ResourceNotFound.new(
              resource: 'Appointment',
              id: params['appointment_date_time']
            )
          )
      end

      def create_claim(appt_id)
        Rails.logger.info(message: 'Create complex claim')
        claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

        claim['claimId']
      end
    end
  end
end
