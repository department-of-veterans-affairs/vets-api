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
    # @param pagination_params [Hash] Parameters for pagination when fetching appointments
    # @return [Hash] Response containing draft appointment data or error information
    #
    def call(referral_id, pagination_params)
      referral_data = fetch_referral_data(referral_id)

      validate_referral_data(referral_data)
      check_referral_usage(referral_id, pagination_params)

      draft_appointment = create_draft_appointment(referral_id)
      provider = fetch_provider(referral_data[:provider_id])
      slots = fetch_provider_slots(referral_data)
      drive_time = fetch_drive_times(@user, provider)

      build_response(draft_appointment, provider, slots, drive_time)
    rescue ServiceError => e
      e.to_response
    rescue => e
      ServiceError.new(
        'Unexpected error occurred in draft appointment service',
        status: nil,
        detail: e.message
      ).to_response
    end

    private

    attr_reader :eps_provider_service, :appointments_service, :eps_appointment_service

    ##
    # Retrieves referral data from Redis cache
    #
    # @param referral_id [String] The referral identifier
    # @return [Hash] The referral data
    # @raise [ServiceError] If referral data cannot be retrieved
    #
    def fetch_referral_data(referral_id)
      eps_redis_client = Eps::RedisClient.new
      eps_redis_client.fetch_referral_attributes(referral_number: referral_id)
    rescue Redis::BaseError => e
      raise ServiceError.new(
        'Failed to retrieve referral data from cache',
        status: :bad_gateway,
        detail: e.message
      )
    end

    ##
    # Validates that all required referral data attributes are present
    #
    # @param referral_data [Hash, nil] The referral data from the cache
    # @raise [ServiceError] If data is invalid or missing required attributes
    #
    def validate_referral_data(referral_data)
      return if referral_data.present? && required_attributes_present?(referral_data)

      missing = missing_required_attributes(referral_data)

      raise ServiceError.new(
        'Invalid referral data',
        status: :unprocessable_entity,
        detail: "Required referral data is missing or incomplete: #{missing}"
      )
    end

    ##
    # Checks if all required attributes are present in the referral data
    #
    # @param referral_data [Hash] The referral data
    # @return [Boolean] true if all required attributes are present
    #
    def required_attributes_present?(referral_data)
      required_attributes.all? { |attr| referral_data[attr].present? }
    end

    ##
    # Returns the list of required attributes for referral data
    #
    # @return [Array<Symbol>] Array of required attribute keys
    #
    def required_attributes
      %i[provider_id appointment_type_id start_date end_date]
    end

    ##
    # Determines which required attributes are missing from the referral data
    #
    # @param referral_data [Hash, nil] The referral data
    # @return [String] Comma-separated list of missing attributes
    #
    def missing_required_attributes(referral_data)
      return 'all required attributes' if referral_data.nil?

      missing = required_attributes.select { |attr| referral_data[attr].blank? }
      missing.empty? ? 'none' : missing.map(&:to_s).join(', ')
    end

    ##
    # Checks if a referral is already in use by cross-referencing referral number against complete
    # list of existing appointments
    #
    # @param referral_id [String] The referral number to check
    # @param pagination_params [Hash] Parameters for pagination when fetching appointments
    # @raise [ServiceError] If the referral is already in use or if checking fails
    #
    # TODO: pass in date from cached referral data to use as range for CCRA appointments call
    def check_referral_usage(referral_id, pagination_params)
      check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)

      if check[:error]
        raise ServiceError.new(
          'Upstream error checking if referral is already in use',
          status: :bad_gateway,
          detail: check[:failures]
        )
      elsif check[:exists]
        raise ServiceError.new(
          'Referral is already used for an existing appointment',
          status: :unprocessable_entity,
          detail: "Referral #{referral_id} is already associated with an existing appointment"
        )
      end
    end

    ##
    # Creates a draft appointment using the provided referral ID
    #
    # @param referral_id [String] The referral identifier
    # @return [Object] The created draft appointment
    # @raise [ServiceError] If draft appointment creation fails
    #
    def create_draft_appointment(referral_id)
      eps_appointment_service.create_draft_appointment(referral_id:)
    end

    ##
    # Fetches provider information by ID
    #
    # @param provider_id [String] The provider's ID
    # @return [Object] Provider information
    # @raise [ServiceError] If provider information cannot be fetched
    #
    def fetch_provider(provider_id)
      eps_provider_service.get_provider_service(provider_id:)
    end

    ##
    # Fetches available provider slots using referral data
    #
    # @param referral_data [Hash] Includes:
    #   - `:provider_id` [String] The provider's ID
    #   - `:appointment_type_id` [String] The appointment type
    #   - `:start_date` [String] The earliest appointment date (ISO 8601)
    #   - `:end_date` [String] The latest appointment date (ISO 8601)
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

    ##
    # Error class for DraftAppointmentService errors
    #
    class ServiceError < StandardError
      attr_reader :status, :error_type, :detail

      ##
      # Initialize a new ServiceError
      #
      # @param message [String] Error message
      # @param status [Symbol, Integer, nil] HTTP status code for the error response
      # @param detail [String, nil] Detailed error information
      # @param error_type [String, nil] Custom error type identifier
      #
      def initialize(message, status: nil, detail: nil)
        @status = status || extract_status(detail)
        @detail = detail
        super(message)
      end

      ##
      # Extracts a status code from an error message if possible
      #
      # @param error_message [String, nil] Error message that might contain a status code
      # @return [Symbol, Integer] Extracted status code, converts 500 to :bad_gateway,
      # or default :bad_gateway if no code found
      #
      def extract_status(error_message)
        return :bad_gateway unless error_message.is_a?(String)

        if (match = error_message.match(/(?:code:|:code\s*=>)\s*["']VAOS_(\d{3})["']/i))
          status_code = match[1].to_i
          return status_code == 500 ? :bad_gateway : status_code
        end

        :bad_gateway
      end

      ##
      # Formats the error into a standard API response
      #
      # @return [Hash] Hash containing error details and HTTP status
      #
      def to_response
        {
          json: {
            errors: [{
              title: message,
              detail:,
              code: 'Eps::DraftAppointmentService::ServiceError'
            }]
          },
          status:
        }
      end
    end
  end
end
