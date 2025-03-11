# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    ##
    # Get a specific appointment from EPS by ID
    #
    # @param appointment_id [String] The ID of the appointment to retrieve
    # @param retrieve_latest_details [Boolean] Whether to fetch latest details from provider service
    # @raise [ArgumentError] If appointment_id is blank
    # @return OpenStruct response from EPS get appointment endpoint
    #
    def get_appointment(appointment_id:, retrieve_latest_details: false)
      query_params = retrieve_latest_details ? '?retrieveLatestDetails=true' : ''

      response = perform(:get, "/#{config.base_path}/appointments/#{appointment_id}#{query_params}", {}, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Get appointments data from EPS
    #
    # @return OpenStruct response from EPS appointments endpoint
    #
    def get_appointments
      response = perform(:get, "/#{config.base_path}/appointments?patientId=#{patient_id}",
                         {}, headers)
      appointments = response.body[:appointments]
      merged_appointments = merge_provider_data_with_appointments(appointments)
      OpenStruct.new(data: merged_appointments)
    end

    ##
    # Creates a draft appointment and fetches all related data needed for the frontend
    #
    # @param referral_id [String] The referral ID to use for the appointment
    # @param pagination_params [Hash] Pagination parameters to use when checking existing appointments
    # @return [Hash] A result hash with the following structure:
    #   - On success: { success: true, data: <appointment_data> }
    #   - On failure: { success: false, error: <error_message>, status: <http_status_code> }
    #
    def create_draft_appointment(referral_id, pagination_params = {})
      result = fetch_cached_referral_data(referral_id)
      return { success: false, error: result[:error], status: result[:status] } unless result[:success]

      cached_referral_data = result[:data]
      validation_result = validate_referral_data(referral_id, cached_referral_data)
      return validation_result[:error_response] unless validation_result[:valid]

      referral_check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)
      existing_appointment_result = check_for_existing_appointment(referral_id, referral_check)
      return existing_appointment_result[:error_response] unless existing_appointment_result[:valid]

      components = collect_draft_appointment_components(referral_id, cached_referral_data)
      return components[:error_response] if components[:error]

      build_draft_appointment_response(components)
    rescue Common::Exceptions::BackendServiceException => e
      handle_service_exception(e, referral_id)
    rescue => e
      Rails.logger.error('Error creating draft appointment', { referral_id:, error: e.message })
      { success: false, error: 'Error creating draft appointment', status: :internal_server_error }
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
    # @return OpenStruct response from EPS submit appointment endpoint
    #
    def submit_appointment(appointment_id, params = {})
      raise ArgumentError, 'appointment_id is required and cannot be blank' if appointment_id.blank?

      required_params = %i[network_id provider_service_id slot_ids referral_number]
      missing_params = required_params - params.keys

      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

      payload = build_submit_payload(params)

      response = perform(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", payload, headers)
      OpenStruct.new(response.body)
    end

    private

    ##
    # Fetch referral data from Redis cache with error handling
    #
    # @param referral_id [String] The referral ID to fetch from cache
    # @return [Hash] Hash with structure { success: true/false, data: <data>, error: <error_message>, status: <status_code> }
    #
    def fetch_cached_referral_data(referral_id)
      data = redis_client.fetch_referral_attributes(referral_number: referral_id)
      { success: true, data: data }
    rescue Redis::BaseError => e
      Rails.logger.error('Redis error fetching referral data', { referral_id: referral_id, error: e.message })
      { success: false, error: 'Unable to retrieve referral data from cache', status: :bad_gateway }
    rescue => e
      Rails.logger.error('Unexpected error fetching referral data from cache', { referral_id: referral_id, error: e.message })
      { success: false, error: 'Unable to retrieve referral data', status: :internal_server_error }
    end

    ##
    # Collect all necessary components for a draft appointment
    #
    # @param referral_id [String] The referral ID for the appointment
    # @param referral_data [Hash] The referral data with provider information
    # @return [Hash] Hash containing all draft appointment components or error information
    #
    def collect_draft_appointment_components(referral_id, referral_data)
      operations = [
        { key: :draft, action: ->(_) { attempt_draft_creation(referral_id) } },
        { key: :provider, action: ->(_) { fetch_provider_data(referral_id, referral_data[:provider_id]) } },
        { key: :slots, action: ->(_) { fetch_provider_slots(referral_id, referral_data) } },
        { key: :drive_time, action: ->(results) { calculate_drive_times(referral_id, results[:provider]) } }
      ]

      results = {}

      operations.each do |operation|
        result = operation[:action].call(results)
        return { error: true, error_response: result[:error_response] } if result[:error]

        results[operation[:key]] = result[:data]
      end

      { error: false, **results }
    end

    ##
    # Handle service exceptions with proper status code mapping
    #
    # @param exception [Common::Exceptions::BackendServiceException] The exception to handle
    # @param referral_id [String] The referral ID for context in logging
    # @return [Hash] Formatted error response
    #
    def handle_service_exception(exception, referral_id)
      status = exception.status
      Rails.logger.error('Backend service error', { referral_id:, error: exception.message, status: })

      mapped_status = map_http_status(status)
      { success: false, error: exception.message, status: mapped_status }
    end

    ##
    # Validate referral data has required fields
    #
    # @param referral_id [String] The referral ID for context in logging
    # @param cached_referral_data [Hash] The referral data to validate
    # @return [Hash] Result with :valid flag and :error_response if invalid
    #
    def validate_referral_data(referral_id, cached_referral_data)
      required_fields = %i[provider_id appointment_type_id start_date end_date]
      missing_fields = required_fields.select { |field| cached_referral_data[field].nil? }

      if missing_fields.empty?
        { valid: true }
      else
        Rails.logger.error('Missing referral data fields',
                           { referral_id:, missing_fields: })
        {
          valid: false,
          error_response: {
            success: false,
            error: "Referral data is incomplete. Missing: #{missing_fields.join(', ')}",
            status: :bad_gateway
          }
        }
      end
    end

    ##
    # Check if an appointment already exists for the given referral
    #
    # @param referral_id [String] The referral ID for context in logging
    # @param referral_check [Hash] The referral check result to validate
    # @return [Hash] Result with :valid flag and :error_response if invalid
    #
    def check_for_existing_appointment(referral_id, referral_check)
      return { valid: true } unless referral_check[:error] || referral_check[:exists]

      if referral_check[:error]
        Rails.logger.error('Error checking appointments', { failures: referral_check[:failures] })
        error_message = "Error checking appointments: #{referral_check[:failures]}"
        status = :bad_gateway
      else # referral_check[:exists]
        Rails.logger.info('Referral already used', { referral_id: })
        error_message = 'No new appointment created: referral is already used'
        status = :unprocessable_entity
      end

      {
        valid: false,
        error_response: { success: false, error: error_message, status: }
      }
    end

    ##
    # Attempt to create a draft appointment and handle any errors
    #
    # @param referral_id [String] The referral ID to use for the appointment
    # @return [Hash] Result hash with error status and appropriate data
    #
    def attempt_draft_creation(referral_id)
      draft_appointment = persist_draft_appointment(referral_id:)
      { error: false, data: draft_appointment }
    rescue Common::Exceptions::BackendServiceException => e
      Rails.logger.error('Error creating draft appointment',
                         { referral_id:, error: e.message })
      {
        error: true,
        error_response: { success: false, error: 'Error creating draft appointment', status: :bad_request }
      }
    end

    ##
    # Fetch provider data from provider service
    #
    # @param referral_id [String] The referral ID for context in logging
    # @param provider_id [String] The provider ID to retrieve
    # @return [Hash] Result hash with provider data or error information
    #
    def fetch_provider_data(referral_id, provider_id)
      provider = provider_services.get_provider_service(provider_id:)
      { error: false, data: provider }
    rescue Common::Exceptions::BackendServiceException => e
      Rails.logger.error('Error fetching provider data',
                         { referral_id:, error: e.message })
      {
        error: true,
        error_response: { success: false, error: 'Error fetching provider data', status: :not_found }
      }
    end

    ##
    # Retrieve available slots for a provider
    #
    # @param referral_id [String] The referral ID for context in logging
    # @param referral_data [Hash] The referral data containing provider and appointment information
    # @return [Hash] Result hash with slot data or error information
    #
    def fetch_provider_slots(referral_id, referral_data)
      slots = provider_services.get_provider_slots(
        referral_data[:provider_id],
        {
          appointmentTypeId: referral_data[:appointment_type_id],
          startOnOrAfter: referral_data[:start_date],
          startBefore: referral_data[:end_date]
        }
      )

      { error: false, data: slots }
    rescue Common::Exceptions::BackendServiceException => e
      Rails.logger.error('Error fetching provider slots',
                         { referral_id:, error: e.message })
      {
        error: true,
        error_response: { success: false, error: 'Error fetching provider slots', status: :bad_request }
      }
    end

    ##
    # Calculate drive times between user and provider
    #
    # @param referral_id [String] The referral ID for context in logging
    # @param provider [OpenStruct] The provider data containing location information
    # @return [Hash] Result hash with drive time data or error information
    #
    def calculate_drive_times(referral_id, provider)
      drive_time = fetch_drive_times(provider)
      { error: false, data: drive_time }
    rescue Common::Exceptions::BackendServiceException => e
      Rails.logger.error('Error fetching drive times',
                         { referral_id:, error: e.message })
      {
        error: true,
        error_response: { success: false, error: 'Error fetching drive times', status: :bad_request }
      }
    end

    ##
    # Map HTTP status code to symbolic representation
    #
    # @param status [Integer] The numeric HTTP status code
    # @return [Symbol] The corresponding symbolic HTTP status
    #
    def map_http_status(status)
      case status
      when 400
        :bad_request
      when 404
        :not_found
      else
        :bad_gateway
      end
    end

    ##
    # Create a draft appointment in EPS by making an API call to the EPS endpoint
    #
    # @param referral_id [String] The referral ID to use for the appointment
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def persist_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
    end

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
    # Calculates drive times between user's address and provider location
    #
    # @param provider [OpenStruct] The provider data containing location information
    # @return [Hash, nil] Drive time data or nil if user address is incomplete
    #
    def fetch_drive_times(provider)
      user_address = user.vet360_contact_info&.residential_address

      return nil unless user_address&.latitude && user_address.longitude

      provider_services.get_drive_times(
        destinations: {
          provider.id => {
            latitude: provider.location[:latitude],
            longitude: provider.location[:longitude]
          }
        },
        origin: {
          latitude: user_address.latitude,
          longitude: user_address.longitude
        }
      )
    end

    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end

    def appointments_service
      @appointments_service ||= VAOS::V2::AppointmentsService.new(user)
    end

    ##
    # Build a successful response from draft appointment components
    #
    # @param components [Hash] The components of a draft appointment
    # @return [Hash] Success response with appointment data
    #
    def build_draft_appointment_response(components)
      response_data = OpenStruct.new(
        id: components[:draft].id,
        provider: components[:provider],
        slots: components[:slots],
        drive_time: components[:drive_time]
      )

      { success: true, data: response_data }
    end
  end
end
