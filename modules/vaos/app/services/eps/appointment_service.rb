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

      with_monitoring do
        response = perform(:get, "/#{config.base_path}/appointments/#{appointment_id}#{query_params}", {},
                           request_headers_with_correlation_id)
        result = OpenStruct.new(response.body)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(result, response, 'get_appointment')

        result
      end
    end

    ##
    # Get appointments data from EPS
    #
    # @return OpenStruct response from EPS appointments endpoint
    #
    def get_appointments
      with_monitoring do
        response = perform(:get, "/#{config.base_path}/appointments?patientId=#{patient_id}",
                           {}, request_headers_with_correlation_id)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(response.body, response, 'get_appointments')

        appointments = response.body[:appointments]
        merged_appointments = merge_provider_data_with_appointments(appointments)
        OpenStruct.new(data: merged_appointments)
      end
    end

    ##
    # Create draft appointment in EPS
    #
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def create_draft_appointment(referral_id:)
      with_monitoring do
        response = perform(:post, "/#{config.base_path}/appointments",
                           { patientId: patient_id, referral: { referralNumber: referral_id } },
                           request_headers_with_correlation_id)

        result = OpenStruct.new(response.body)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(result, response, 'create_draft_appointment')

        result
      end
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
      raise ArgumentError, 'Email is required' if user.email.blank?

      required_params = %i[network_id provider_service_id slot_ids referral_number]
      missing_params = required_params - params.keys

      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

      payload = build_submit_payload(params)

      # Store appointment data in Redis using the RedisClient
      redis_client.store_appointment_data(
        uuid: user.uuid,
        appointment_id:,
        email: user.va_profile_email
      )

      # Enqueue worker with UUID and last 4 of appointment_id
      appointment_last4 = appointment_id.to_s.last(4)
      Eps::AppointmentStatusJob.perform_async(user.uuid, appointment_last4)

      with_monitoring do
        response = perform(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", payload,
                           request_headers_with_correlation_id)

        result = OpenStruct.new(response.body)

        # Check for error field in successful responses using reusable helper
        check_for_eps_error!(result, response, 'submit_appointment')

        result
      end
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
    # Get instance of RedisClient
    #
    # @return [Eps::RedisClient] RedisClient instance
    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end
  end
end
