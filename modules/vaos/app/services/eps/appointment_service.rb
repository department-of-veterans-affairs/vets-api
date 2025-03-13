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
    # Create draft appointment in EPS
    #
    # @param referral_id [String] The ID of the referral to use for the draft appointment
    # @return OpenStruct response from EPS create draft appointment endpoint
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def create_draft_appointment(referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error("Draft appointment error: #{e.message}")
      status = :bad_request

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: DRAFT_APPOINTMENT_ERROR_MSG,
            detail: "Unable to create draft appointment: #{e.message}"
          }]
        },
        status: status
      }
    rescue => e
      Rails.logger.error("Draft appointment error: #{e.message}")

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: DRAFT_APPOINTMENT_ERROR_MSG,
            detail: "Unexpected error creating draft appointment: #{e.message}"
          }]
        },
        status: :bad_request
      }
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
    # @param user [User] The current user
    # @param pagination_params [Hash] Optional pagination parameters for referral usage check
    # @return [Hash] Result hash:
    #   - If successful: { success: true, response_data: OpenStruct }
    #   - If validation fails: { success: false, json: { errors: [...] }, status: Symbol }
    #
    def create_draft_appointment_with_response(referral_id:, user:, pagination_params: {})
      # Use the validation step to create a draft appointment
      validation_result = create_draft_appointment_with_validation(
        referral_id: referral_id,
        pagination_params: pagination_params
      )

      return validation_result unless validation_result[:success]

      # Build the complete response with provider, slots and drive time information
      response_data = build_draft_appointment_response(
        validation_result[:draft_appointment],
        validation_result[:referral_data],
        user
      )

      # If response_data is a hash with an error key, it's an error response
      if response_data.is_a?(Hash) && response_data[:error]
        # Explicitly preserve the status code from the error
        return response_data
      end

      { success: true, response_data: response_data }
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
    # Get instance of AppointmentsService
    #
    # @return [VAOS::V2::AppointmentsService] AppointmentsService instance
    def appointments_service
      @appointments_service ||= VAOS::V2::AppointmentsService.new(user)
    end

    ##
    # Get instance of RedisClient
    #
    # @return [Eps::RedisClient] RedisClient instance
    def redis_client
      @redis_client ||= Eps::RedisClient.new
    end

    ##
    # Get instance of ProviderService
    #
    # @return [Eps::ProviderService] ProviderService instance
    def provider_service
      @provider_service ||= Eps::ProviderService.new(user)
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
    #   - If successful: { success: true, draft_appointment: OpenStruct, referral_data: Hash }
    #   - If validation fails: { success: false, json: { errors: [...] }, status: Symbol }
    #
    def create_draft_appointment_with_validation(referral_id:, pagination_params: {})
      referral_data = fetch_referral_attributes(referral_number: referral_id)
      return referral_data if referral_data.is_a?(Hash) && referral_data[:error]

      validation_result = build_referral_validation_response(referral_data)
      return validation_result unless validation_result[:success]

      usage_result = check_referral_usage(referral_id, pagination_params)
      return usage_result unless usage_result[:success]

      draft_appointment = create_draft_appointment(referral_id: referral_id)
      return draft_appointment if draft_appointment.is_a?(Hash) && draft_appointment[:error]

      {
        success: true,
        draft_appointment:,
        referral_data:
      }
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

      {
        valid: missing_attributes.empty?,
        missing_attributes: missing_attributes.map(&:to_s)
      }
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
        {
          success: false,
          json: {
            errors: [{
              title: 'Invalid referral data',
              detail: "Required referral data is missing or incomplete: #{validation_result[:missing_attributes].join(', ')}"
            }]
          },
          status: :unprocessable_entity
        }
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
        {
          success: false,
          json: {
            errors: [{
              title: 'Error checking appointments',
              detail: "Error checking if referral is already used: #{check[:failures]}"
            }]
          },
          status: :bad_gateway
        }
      elsif check[:exists]
        {
          success: false,
          json: {
            errors: [{
              title: 'Referral already used',
              detail: 'No new appointment created: referral is already used'
            }]
          },
          status: :unprocessable_entity
        }
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
      redis_client.fetch_referral_attributes(referral_number: referral_number)
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error: #{e.message}")
      StatsD.increment('api.vaos.va_mobile.response.partial.redis_error')
      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: CACHE_ERROR_MSG,
            detail: "Unable to connect to cache service: #{e.message}"
          }]
        },
        status: :bad_gateway
      }
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
      status = e.status || :bad_gateway
      Rails.logger.error("Provider slots error: #{e.message}")
      StatsD.increment('api.vaos.va_mobile.response.partial.provider_slots_error')

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: PROVIDER_SLOTS_ERROR_MSG,
            detail: "Unexpected error fetching provider slots: #{e.message}"
          }]
        },
        status:
      }
    end

    ##
    # Gets provider service information by ID
    #
    # @param provider_id [String] The provider ID
    # @return [OpenStruct] The provider service information
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def get_provider_service(provider_id:)
      provider_service.get_provider_service(provider_id: provider_id)
    rescue => e
      Rails.logger.error("Provider service error: #{e.message}")

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: PROVIDER_ERROR_MSG,
            detail: "Unexpected error fetching provider information: #{e.message}"
          }]
        },
        status: :not_found
      }
    end

    ##
    # Gets drive times for a provider
    #
    # @param provider [OpenStruct] The provider object with location information
    # @param user [User] The current user with address information
    # @return [Hash, nil] Drive time information or nil if not available
    #   - On error: returns { error: true, json: { errors: [...] }, status: appropriate_status }
    #
    def get_drive_times(provider, user)
      user_address = user.vet360_contact_info&.residential_address

      return nil unless user_address&.latitude && user_address&.longitude

      provider_service.get_drive_times(
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
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error("Drive times error: #{e.message}")
      status = :bad_request if e.status == 400

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: DRIVE_TIME_ERROR_MSG,
            detail: "Invalid coordinates for drive time calculation: #{e.message}"
          }]
        },
        status: status || :bad_request # Default to bad_request for drive time errors
      }
    rescue => e
      Rails.logger.error("Drive times error: #{e.message}")

      {
        error: true,
        success: false,
        json: {
          errors: [{
            title: DRIVE_TIME_ERROR_MSG,
            detail: "Unexpected error calculating drive times: #{e.message}"
          }]
        },
        status: :bad_request # Default to bad_request for drive time errors
      }
    end

    ##
    # Builds the complete response data for a draft appointment
    #
    # @param draft_appointment [OpenStruct] The draft appointment object
    # @param referral_data [Hash] The referral data
    # @param user [User] The current user
    # @return [OpenStruct] The complete response data or error hash
    #
    def build_draft_appointment_response(draft_appointment, referral_data, user)
      provider = get_provider_service(provider_id: referral_data[:provider_id])
      return provider if provider.is_a?(Hash) && provider[:error]

      slots = fetch_provider_slots(referral_data)
      if slots.is_a?(Hash) && slots[:error]
        return slots
      end

      drive_time = get_drive_times(provider, user)
      if drive_time.is_a?(Hash) && drive_time[:error]
        return drive_time
      end

      OpenStruct.new(
        id: draft_appointment.id,
        provider: provider,
        slots: slots,
        drive_time: drive_time
      )
    end
  end
end
