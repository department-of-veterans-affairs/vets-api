# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    ##
    # Get a specific appointment from EPS by ID
    #
    # @param appointment_id [String] The ID of the appointment to retrieve
    # @param retrieve_latest_details [Boolean] Whether to fetch latest details from provider service
    # @raise [ArgumentError] If appointment_id is blank
    # @raise [VAOS::Exceptions::BackendServiceException] If response contains error field
    # @return OpenStruct response from EPS get appointment endpoint
    #
    def get_appointment(appointment_id:, retrieve_latest_details: false)
      query_params = retrieve_latest_details ? '?retrieveLatestDetails=true' : ''

      response = perform(:get, "/#{config.base_path}/appointments/#{appointment_id}#{query_params}", {},
                         request_headers)

      result = OpenStruct.new(response.body)
      
      # Check for error field in successful responses
      if result.error.present?
        raise_eps_error(result.error, response)
      end
      
      result
    end

    ##
    # Get appointments data from EPS
    #
    # @return OpenStruct response from EPS appointments endpoint
    #
    def get_appointments
      response = perform(:get, "/#{config.base_path}/appointments?patientId=#{patient_id}",
                         {}, request_headers)

      # Check for error field in successful responses  
      if response.body.is_a?(Hash) && response.body[:error].present?
        raise_eps_error(response.body[:error], response)
      end

      appointments = response.body[:appointments]
      merged_appointments = merge_provider_data_with_appointments(appointments)
      OpenStruct.new(data: merged_appointments)
    end

    ##
    # Create draft appointment in EPS
    #
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def create_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referral: { referralNumber: referral_id } }, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    #
    # Submit an appointment to EPS for booking
    #
    # @param appointment_id [String] The ID of the appointment to submit
    # @param params [Hash] Hash containing required and optional parameters
    # @option params [String] :network_id The network ID for the appointment
    # @option params [String] :provider_service_id The provider service ID
    # @option params [Array<String>] :slot_ids Array of slot IDs for the appointment
    # @option params [String] :referral_number The referral number
    # @option params [Hash] :additional_patient_attributes Optional patient details (address, contact info)
    # @raise [ArgumentError] If any required parameters are missing
    # @raise [VAOS::Exceptions::BackendServiceException] If response contains error field
    # @return OpenStruct response from EPS submit appointment endpoint
    #
    def submit_appointment(appointment_id, params = {})
      raise ArgumentError, 'appointment_id is required and cannot be blank' if appointment_id.blank?

      required_params = %i[network_id provider_service_id slot_ids referral_number]
      missing_params = required_params - params.keys

      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

      payload = build_submit_payload(params)

      EpsAppointmentWorker.perform_async(appointment_id, user)
      response = perform(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", payload, request_headers)

      result = OpenStruct.new(response.body)
      
      # Check for error field in successful responses
      if result.error.present?
        raise_eps_error(result.error, response)
      end
      
      result
    end

    private

    ##
    # Merge provider data with appointment data
    #
    # @param appointments [Array<Hash>] Array of appointment data
    # @raise [Common::Exceptions::BackendServiceException] If provider data cannot be fetched
    # @return [Array<Hash>] Array of appointment data with provider data merged in
    def merge_provider_data_with_appointments(appointments)
      return [] if appointments.nil?

      provider_ids = appointments.pluck(:provider_service_id).compact.uniq
      providers = provider_services.get_provider_services_by_ids(provider_ids:)

      appointments.each do |appointment|
        next unless appointment[:provider_service_id]

        provider = providers[:provider_services].find do |provider_data|
          provider_data[:id] == appointment[:provider_service_id]
        end
        appointment[:provider] = provider
      end

      appointments
    end

    def build_submit_payload(params)
      payload = {
        network_id: params[:network_id],
        provider_service_id: params[:provider_service_id],
        slot_ids: params[:slot_ids],
        referral: {
          referral_number: params[:referral_number]
        }
      }

      if params[:additional_patient_attributes]
        payload[:additional_patient_attributes] = params[:additional_patient_attributes]
      end

      payload
    end

    ##
    # Get instance of ProviderService
    #
    # @return [Eps::ProviderService] ProviderService instance
    def provider_services
      @provider_services ||= Eps::ProviderService.new(user)
    end

    ##
    # Raises a VAOS::Exceptions::BackendServiceException for EPS error responses
    #
    # @param error_message [String] The error message from the EPS response
    # @param response [Object] The HTTP response object
    # @raise [VAOS::Exceptions::BackendServiceException]
    def raise_eps_error(error_message, response)
      # Log the error without PII - only include safe context information
      Rails.logger.warn("EPS appointment error detected", {
        error_type: error_message,
        method: caller_locations(1, 1)[0].label,
        status: response.status || 'unknown'
      })

      # Create a sanitized error body that doesn't contain PII
      # Only include the error field and minimal context for debugging
      sanitized_body = {
        error: error_message,
        source: 'EPS appointment service',
        timestamp: Time.current.iso8601
      }.to_json

      # Create a mock env object that matches what VAOS::Exceptions::BackendServiceException expects
      # This follows the same pattern as VAOS::Middleware::Response::Errors but with sanitized body
      mock_env = OpenStruct.new(
        status: 400,  # Use 400 for business logic errors
        body: sanitized_body,
        url: "#{config.api_url}/#{config.base_path}",
        response_body: sanitized_body
      )
      
      raise VAOS::Exceptions::BackendServiceException, mock_env
    end
  end
end
