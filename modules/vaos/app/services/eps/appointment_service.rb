# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    CACHE_ERROR_MSG = 'Error fetching referral data from cache'
    DRIVE_TIME_ERROR_MSG = 'Invalid coordinates for drive time calculation'
    PROVIDER_ERROR_MSG = 'Error fetching provider information'
    PROVIDER_SLOTS_ERROR_MSG = 'Error fetching provider slots'
    DRAFT_APPOINTMENT_ERROR_MSG = 'Error creating draft appointment'

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
    # Create a draft appointment with complete validation and response building
    #
    # This method performs the full process of creating a draft appointment:
    # 1. Fetches and validates referral data from Redis
    # 2. Checks if the referral is already in use
    # 3. Creates a draft appointment if validations pass
    # 4. Builds the complete response with provider, slots and drive time information
    #
    # @param referral_id [String] The referral ID to use
    # @param user_coordinates [Hash] containins user coordinates { latitude:, longitude: }
    # @param pagination_params [Hash] Optional pagination parameters for referral usage check
    # @return [Hash] Result hash:
    #   - If successful: { success: true, response_data: OpenStruct }
    #   - If validation fails: { success: false, json: { errors: [...] }, status: Symbol }
    #
    def create_draft_appointment(referral_id:, user_coordinates:, pagination_params: {})
      validation_result = create_draft_appointment_with_validation(referral_id:, pagination_params:)

      return validation_result if validation_result[:error]

      build_draft_appointment_response(
        validation_result[:draft_appointment],
        validation_result[:referral_data],
        user_coordinates
      )
    end

    ##
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
    # @return [OpenStruct] response from EPS submit appointment endpoint
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
    # Create draft appointment in EPS
    #
    # @param referral_id [String] The ID of the referral to use for the draft appointment
    # @return [OpenStruct] response from EPS create draft appointment endpoint
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def submit_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error("Draft appointment error: #{e.message}")
      build_error_response(DRAFT_APPOINTMENT_ERROR_MSG, "Unable to create draft appointment: #{e.message}",
                           :bad_request)
    rescue => e
      Rails.logger.error("Draft appointment error: #{e.message}")
      build_error_response(DRAFT_APPOINTMENT_ERROR_MSG, "Unexpected error creating draft appointment: #{e.message}",
                           :bad_request)
    end

    ##
    # Builds a standardized error response hash
    #
    # @param title [String] The error title/category
    # @param detail [String] The detailed error message
    # @param status [Symbol] The HTTP status code to return
    # @param stats_key [String, nil] Optional StatsD key for error tracking
    # @return [Hash] Standardized error response hash
    #
    def build_error_response(title, detail, status, stats_key = nil)
      StatsD.increment(stats_key) if stats_key.present?

      {
        error: true,
        json: {
          errors: [{
            title:,
            detail:
          }]
        },
        status:
      }
    end

    ##
    # Merge provider data with appointment data
    #
    # @param appointments [Array<Hash>] Array of appointment data
    # @return [Array<Hash>] Array of appointment data with provider data merged in
    #
    def merge_provider_data_with_appointments(appointments)
      return [] if appointments.nil?

      provider_ids = appointments.pluck(:provider_service_id).compact.uniq
      providers = provider_service.get_provider_services_by_ids(provider_ids:)

      appointments.each do |appointment|
        next unless appointment[:provider_service_id]

        provider = providers[:provider_services].find do |provider_data|
          provider_data[:id] == appointment[:provider_service_id]
        end
        appointment[:provider] = provider
      end

      appointments
    end

    ##
    # Builds the submit payload for an appointment
    #
    # @param params [Hash] Hash containing appointment parameters
    # @return [Hash] Formatted payload for the submit endpoint
    #
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
        payload[:additional_patient_attributes] =
          params[:additional_patient_attributes]
      end

      payload
    end

    ##
    # Get instance of ProviderService
    #
    # @return [Eps::ProviderService] ProviderService instance
    #
    def provider_service
      @provider_service ||= Eps::ProviderService.new(user)
    end

    ##
    # Get instance of AppointmentsService
    #
    # @return [VAOS::V2::AppointmentsService] AppointmentsService instance
    #
    def appointments_service
      @appointments_service ||= VAOS::V2::AppointmentsService.new(user)
    end

    ##
    # Get instance of RedisClient
    #
    # @return [Eps::RedisClient] RedisClient instance
    #
    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end

    ##
    # Create draft appointment in EPS with validation
    #
    # This method performs the following steps:
    # 1. Fetches referral attributes from Redis
    # 2. Validates the referral data
    # 3. Checks if the referral is already in use
    # 4. Creates a draft appointment if validations pass
    #
    # @param referral_id [String] The ID of the referral to use for the draft appointment
    # @param pagination_params [Hash] Optional pagination parameters for referral usage check
    # @return [Hash] Result hash:
    #   - If successful: { draft_appointment: OpenStruct, referral_data: Hash }
    #   - If validation fails: { json: { errors: [...] }, status: Symbol }
    #
    def create_draft_appointment_with_validation(referral_id:, pagination_params: {})
      referral_data = fetch_referral_attributes(referral_number: referral_id)
      return referral_data if referral_data.is_a?(Hash) && referral_data[:error]

      validation_result = build_referral_validation_response(referral_data)
      return validation_result unless validation_result[:success]

      usage_result = check_referral_usage(referral_id, pagination_params)
      return usage_result unless usage_result[:success]

      draft_appointment = submit_draft_appointment(referral_id:)
      return draft_appointment if draft_appointment.is_a?(Hash) && draft_appointment[:error]

      { draft_appointment:, referral_data: }
    end

    ##
    # Validates that all required referral data attributes are present
    #
    # @param referral_data [Hash, nil] The referral data from the cache
    # @return [Hash] Hash with :valid boolean and :missing_attributes array
    #
    def validate_referral_data(referral_data)
      return { valid: false, missing_attributes: ['all required attributes'] } if referral_data.nil?

      required_attributes = %i[provider_id appointment_type_id start_date end_date]
      missing_attributes = required_attributes.select { |attr| referral_data[attr].blank? }

      { valid: missing_attributes.empty?, missing_attributes: missing_attributes.map(&:to_s) }
    end

    ##
    # Builds a formatted response for referral data validation
    #
    # @param referral_data [Hash, nil] The referral data from the cache
    # @return [Hash] Result hash:
    #   - If data is valid: { success: true }
    #   - If data is invalid: { success: false, json: { errors: [...] }, status: :unprocessable_entity }
    #
    def build_referral_validation_response(referral_data)
      validation_result = validate_referral_data(referral_data)
      if validation_result[:valid]
        { success: true }
      else
        build_error_response(
          'Invalid referral data',
          "Required referral data is missing or incomplete: #{validation_result[:missing_attributes].join(', ')}",
          :unprocessable_entity
        )
      end
    end

    ##
    # Checks if a referral is already in use
    #
    # @param referral_id [String] The referral ID to check
    # @param pagination_params [Hash] Optional pagination parameters
    # @return [Hash] Result hash:
    #   - If referral is unused: { success: true }
    #   - If an error occurs: { success: false, json: { errors: [...] }, status: :bad_gateway }
    #   - If referral exists: { success: false, json: { errors: [...] }, status: :unprocessable_entity }
    #
    def check_referral_usage(referral_id, pagination_params = {})
      check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)

      if check[:error]
        build_error_response(
          'Error checking appointments',
          "Error checking if referral is already used: #{check[:failures]}",
          :bad_gateway
        )
      elsif check[:exists]
        build_error_response(
          'Referral already used',
          'No new appointment created: referral is already used',
          :unprocessable_entity
        )
      else
        { success: true }
      end
    end

    ##
    # Fetches referral attributes from Redis
    #
    # @param referral_number [String] The referral number
    # @return [Hash, nil] The referral attributes or nil if not found
    #   - On Redis error: returns { error: true, json: { errors: [...] }, status: :bad_gateway }
    #
    def fetch_referral_attributes(referral_number:)
      redis_client.fetch_referral_attributes(referral_number:)
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error: #{e.message}")
      build_error_response(
        CACHE_ERROR_MSG,
        "Unable to connect to cache service: #{e.message}",
        :bad_gateway,
        'api.vaos.va_mobile.response.partial.redis_error'
      )
    end

    ##
    # Fetches available provider slots using referral data
    #
    # @param referral_data [Hash] Includes:
    #   - `:provider_id` [String] The provider's ID.
    #   - `:appointment_type_id` [String] The appointment type.
    #   - `:start_date` [String] The earliest appointment date (ISO 8601).
    #   - `:end_date` [String] The latest appointment date (ISO 8601).
    #
    # @return [Array, nil] Available slots array or nil if error occurs
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def fetch_provider_slots(referral_data)
      provider_service.get_provider_slots(
        referral_data[:provider_id],
        {
          appointmentTypeId: referral_data[:appointment_type_id],
          startOnOrAfter: referral_data[:start_date],
          startBefore: referral_data[:end_date]
        }
      )
    rescue => e
      status = e.respond_to?(:status) ? e.status : :bad_gateway
      Rails.logger.error("Provider slots error: #{e.message}")
      build_error_response(
        PROVIDER_SLOTS_ERROR_MSG,
        "Unexpected error fetching provider slots: #{e.message}",
        status,
        'api.vaos.va_mobile.response.partial.provider_slots_error'
      )
    end

    ##
    # Gets provider service information by ID
    #
    # @param provider_id [String] The provider ID
    # @return [OpenStruct] The provider service information
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def get_provider_service(provider_id:)
      provider_service.get_provider_service(provider_id:)
    rescue => e
      Rails.logger.error("Provider service error: #{e.message}")
      build_error_response(PROVIDER_ERROR_MSG, "Unexpected error fetching provider information: #{e.message}",
                           :not_found)
    end

    ##
    # Gets drive times for a provider
    #
    # @param provider [OpenStruct] The provider object with location information
    # @param user_coordinates [Hash] Hash containing user coordinates { latitude:, longitude: }
    # @return [Hash, nil] Drive time information or nil if not available
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def get_drive_times(provider, user_coordinates)
      return nil unless user_coordinates[:latitude] && user_coordinates[:longitude]

      provider_service.get_drive_times(
        destinations: {
          provider.id => { latitude: provider.location[:latitude], longitude: provider.location[:longitude] }
        },
        origin: { latitude: user_coordinates[:latitude], longitude: user_coordinates[:longitude] }
      )
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error("Drive times error: #{e.message}")
      status = e.status == 400 ? :bad_request : nil
      build_error_response(DRIVE_TIME_ERROR_MSG, "Invalid coordinates for drive time calculation: #{e.message}",
                           status || :bad_request)
    rescue => e
      Rails.logger.error("Drive times error: #{e.message}")
      build_error_response(DRIVE_TIME_ERROR_MSG, "Unexpected error calculating drive times: #{e.message}", :bad_request)
    end

    ##
    # Builds the complete response data for a draft appointment
    #
    # @param draft_appointment [OpenStruct] The draft appointment object
    # @param referral_data [Hash] The referral data
    # @param user_coordinates [Hash] Hash containing user coordinates { latitude:, longitude: }
    # @return [OpenStruct] The complete response data or error hash
    #
    def build_draft_appointment_response(draft_appointment, referral_data, user_coordinates)
      provider = get_provider_service(provider_id: referral_data[:provider_id])
      return provider if provider.is_a?(Hash) && provider[:error]

      slots = fetch_provider_slots(referral_data)
      return slots if slots.is_a?(Hash) && slots[:error]

      drive_time = get_drive_times(provider, user_coordinates)
      return drive_time if drive_time.is_a?(Hash) && drive_time[:error]

      OpenStruct.new( id: draft_appointment.id, provider:, slots:, drive_time:)
    end
  end
end
