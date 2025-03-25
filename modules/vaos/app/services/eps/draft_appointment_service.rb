# frozen_string_literal: true

module Eps
  ##
  # Service responsible for creating draft appointments based on referrals
  # and gathering necessary related data like providers, slots and drive times.
  #
  class DraftAppointmentService
    ##
    # Initialize the service with the current user
    #
    # @param user [User] The current user
    #
    def initialize(user)
      @user = user
      @appointments_service = VAOS::V2::AppointmentsService.new(user)
      @eps_provider_service = Eps::ProviderService.new(user)
      @eps_appointment_service = Eps::AppointmentService.new(user)
    end

    ##
    # Creates a draft appointment and gathers related information
    #
    # @param referral_id [String] The referral identifier
    # @param pagination_params [Hash] Parameters for pagination
    # @return [Hash] Response containing draft appointment data or error information
    #
    def call(referral_id, pagination_params)
      referral_data = fetch_referral_data(referral_id)
      return referral_data unless referral_data[:success]

      referral_validation = check_referral_data_validation(referral_data)
      return referral_validation unless referral_validation[:success]

      referral_check = check_referral_usage(referral_id, pagination_params)
      return referral_check unless referral_check[:success]

      draft_appointment = create_draft_appointment(referral_id)

      provider = fetch_provider(referral_data[:provider_id])
      slots = fetch_provider_slots(referral_data)

      drive_time = fetch_drive_times(@user, provider)
      build_response(draft_appointment, provider, slots, drive_time)
    end

    private

    attr_reader :eps_provider_service, :appointments_service, :eps_appointment_service

    ##
    # Retrieves referral data from Redis cache
    #
    # @param referral_id [String] The referral identifier
    # @return [Hash, nil] The referral data or nil if not found
    #
    def fetch_referral_data(referral_id)
      eps_redis_client = Eps::RedisClient.new
      eps_redis_client.fetch_referral_attributes(referral_number: referral_id)
    rescue Redis::BaseError => e
      {
        success: false,
        json: { errors: [{ title: 'Error fetching referral data from cache', detail: e.message }] },
        status: :bad_gateway
      }
    end

    ##
    # Validates referral data and builds a formatted response object
    #
    # @param referral_data [Hash, nil] The referral data from the cache
    # @return [Hash] Result hash:
    #   - If data is valid: { success: true }
    #   - If data is invalid: { success: false, json: { errors: [...] }, status: :unprocessable_entity }
    def check_referral_data_validation(referral_data)
      validation_result = validate_referral_data(referral_data)
      if validation_result[:valid]
        { success: true }
      else
        missing_attributes = validation_result[:missing_attributes]

        {
          success: false,
          json: {
            errors: [{
              title: 'Invalid referral data',
              detail: "Required referral data is missing or incomplete: #{missing_attributes}"
            }]
          },
          status: :unprocessable_entity
        }
      end
    end

    ##
    # Validates that all required referral data attributes are present
    #
    # @param referral_data [Hash, nil] The referral data from the cache
    # @return [Hash] Hash with :valid boolean and :missing_attributes array
    ##
    def validate_referral_data(referral_data)
      return { valid: false, missing_attributes: ['all required attributes'] } if referral_data.nil?

      required_attributes = %i[provider_id appointment_type_id start_date end_date]
      missing_attributes = required_attributes.select { |attr| referral_data[attr].blank? }

      {
        valid: missing_attributes.empty?,
        missing_attributes: missing_attributes.map(&:to_s).join(', ')
      }
    end

    ##
    # Checks if a referral is already in use by cross referrencing referral number against complete
    # list of existing appointments
    #
    # @param referral_id [String] the referral number to check.
    # @param pagination_params [Hash] Parameters for pagination when fetching appointments
    # @return [Hash] Result hash:
    #   - If referral is unused: { success: true }
    #   - If an error occurs: { success: false, json: { message: ... }, status: :bad_gateway }
    #   - If referral exists: { success: false, json: { message: ... }, status: :unprocessable_entity }
    #
    # TODO: pass in date from cached referral data to use as range for CCRA appointments call
    def check_referral_usage(referral_id, pagination_params)
      check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)

      if check[:error]
        { success: false, json: { message: "Error checking appointments: #{check[:failures]}" },
          status: :bad_gateway }
      elsif check[:exists]
        { success: false, json: { message: 'No new appointment created: referral is already used' },
          status: :unprocessable_entity }
      else
        { success: true }
      end
    end

    ##
    # Creates a draft appointment using the provided referral ID
    #
    # @param referral_id [String] The referral identifier
    # @return [Object] The created draft appointment
    #
    def create_draft_appointment(referral_id)
      eps_appointment_service.create_draft_appointment(referral_id:)
    end

    ##
    # Fetches provider information by ID
    #
    # @param provider_id [String] The provider's ID
    # @return [Object] Provider information
    #
    def fetch_provider(provider_id)
      eps_provider_service.get_provider_service(provider_id:)
    end

    ##
    # Fetches available provider slots using referral data.
    #
    # @param referral_data [Hash] Includes:
    #   - `:provider_id` [String] The provider's ID.
    #   - `:appointment_type_id` [String] The appointment type.
    #   - `:start_date` [String] The earliest appointment date (ISO 8601).
    #   - `:end_date` [String] The latest appointment date (ISO 8601).
    #
    # @return [Array, nil] Available slots array or nil if error occurs
    #
    def fetch_provider_slots(referral_data)
      eps_provider_service.get_provider_slots(
        referral_data[:provider_id],
        {
          appointmentTypeId: referral_data[:appointment_type_id],
          startOnOrAfter: referral_data[:start_date],
          startBefore: referral_data[:end_date]
        }
      )
    end

    ##
    # Fetches drive time estimates from user's location to provider's location
    #
    # @param user [User] The current user
    # @param provider [Object] The provider information including location
    # @return [Object, nil] Drive time information or nil if user address is incomplete
    #
    def fetch_drive_times(user, provider)
      user_address = user.vet360_contact_info&.residential_address

      return nil unless user_address&.latitude && user_address.longitude

      eps_provider_service.get_drive_times(
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

    ##
    # Builds the response object with the draft appointment and related information
    #
    # @param draft_appointment [Object] The created draft appointment
    # @param provider [Object] The provider information
    # @param slots [Array] Available appointment slots
    # @param drive_time [Object, nil] Drive time information
    # @return [Hash] Response hash with serialized data and status
    #
    def build_response(draft_appointment, provider, slots, drive_time)
      response_data = OpenStruct.new(id: draft_appointment.id, provider:, slots:, drive_time:)
      serialized = Eps::DraftAppointmentSerializer.new(response_data)
      { json: serialized, status: :created }
    end
  end
end
