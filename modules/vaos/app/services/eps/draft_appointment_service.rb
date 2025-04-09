# frozen_string_literal: true

require_relative 'draft_appointment_service_error'

module Eps
  ##
  # Service responsible for creating draft appointments based on referrals
  # and gathering necessary related data like providers, slots and drive times.
  #
  class DraftAppointmentService
    attr_reader :eps_provider_service, :appointments_service, :eps_appointment_service, :user

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
    # @return [OpenStruct] A structure containing:
    #   - `:id` [String] The ID of the created draft appointment
    #   - `:provider` [Object] The provider information
    #   - `:slots` [Object] Available appointment slots
    #   - `:drive_time` [Object, nil] Drive time information or nil if user address is incomplete
    # @raise [DraftAppointmentServiceError] If an error occurs during the process
    #
    def create_draft_appointment(referral_id, pagination_params)
      validate_referral_id(referral_id)
      referral_data = fetch_referral_data(referral_id)

      validate_referral_data(referral_data)
      check_referral_usage(referral_id, pagination_params)

      provider = get_provider(referral_data[:provider_id])
      slots = fetch_provider_slots(referral_data)
      drive_time = fetch_drive_times(user, provider)
      draft_appointment = submit_draft_appointment(referral_id)

      OpenStruct.new(id: draft_appointment.id, provider:, slots:, drive_time:)
    rescue DraftAppointmentServiceError => e
      raise e
    rescue => e
      raise_service_error('Unexpected error occurred in draft appointment service', e.message)
    end

    private

    ##
    # Validates that the referral ID is present and valid
    #
    # @param referral_id [String] The referral identifier
    # @raise [DraftAppointmentServiceError] If referral ID is missing or invalid
    #
    def validate_referral_id(referral_id)
      if referral_id.blank?
        raise_service_error(
          'Missing referral ID',
          'A valid referral ID is required to create a draft appointment'
        )
      end
    end

    ##
    # Retrieves referral data from Redis cache
    #
    # @param referral_id [String] The referral identifier
    # @return [Hash] The referral data containing provider_id, appointment_type_id, start_date, and end_date
    # @raise [DraftAppointmentServiceError] If referral data cannot be retrieved or cache is unavailable
    #
    def fetch_referral_data(referral_id)
      with_error_handling('retrieve referral data') do
        eps_redis_client = Eps::RedisClient.new
        eps_redis_client.fetch_referral_attributes(referral_number: referral_id)
      end
    end

    ##
    # Validates that all required referral data attributes are present
    #
    # @param referral_data [Hash, nil] The referral data from the cache
    # @return [Boolean] true if all required attributes are present
    # @raise [DraftAppointmentServiceError] If data is invalid or missing required attributes
    #
    def validate_referral_data(referral_data)
      return true if referral_data.present? && required_attributes_present?(referral_data)

      missing = missing_required_attributes(referral_data)

      raise_service_error(
        'Invalid referral data',
        "Required referral data is missing or incomplete: #{missing}",
        :unprocessable_entity
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
    # @raise [DraftAppointmentServiceError] If the referral is already in use or if checking fails
    # @return [nil] If the referral is not in use
    #
    # TODO: pass in date from cached referral data to use as range for CCRA appointments call
    def check_referral_usage(referral_id, pagination_params)
      referral_usage_check = {}
      with_error_handling('check referral usage') do
        referral_usage_check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)
      end

      if referral_usage_check[:error]
        detail = referral_usage_check[:failures] || 'Unknown upstream error'
        raise_service_error('Failed to check if referral is already in use', detail)
      elsif referral_usage_check[:exists]
        raise_service_error('Error checking referral usage',
                            'Referral is already associated with an existing appointment',
                            :unprocessable_entity)
      end
    end

    ##
    # Fetches the provider information
    #
    # @param provider_id [String] The provider's ID
    # @return [Object] The provider information
    # @raise [DraftAppointmentServiceError] If provider data cannot be fetched
    #
    def get_provider(provider_id)
      with_error_handling('fetch provider') do
        eps_provider_service.get_provider_service(provider_id:)
      end
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
    # @return [Object] Available slots information
    # @raise [DraftAppointmentServiceError] If slots cannot be fetched
    #
    def fetch_provider_slots(referral_data)
      with_error_handling('fetch provider slots') do
        eps_provider_service.get_provider_slots(
          referral_data[:provider_id],
          {
            appointmentTypeId: referral_data[:appointment_type_id],
            startOnOrAfter: referral_data[:start_date],
            startBefore: referral_data[:end_date]
          }
        )
      end
    end

    ##
    # Fetches drive time estimates from user's location to provider's location
    #
    # @param user [User] The current user
    # @param provider [Object] The provider information including location
    # @return [Object, nil] Drive time information or nil if user address is incomplete
    # @raise [DraftAppointmentServiceError] If drive time calculation fails
    #
    def fetch_drive_times(user, provider)
      user_address = user.vet360_contact_info&.residential_address

      return nil unless user_address&.latitude && user_address.longitude

      with_error_handling('fetch drive times') do
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
    end

    ##
    # Submits a draft appointment
    #
    # @param referral_id [String] The referral ID to use for the draft appointment
    # @return [Object] The created draft appointment object
    # @raise [DraftAppointmentServiceError] If the draft appointment creation fails
    #
    def submit_draft_appointment(referral_id)
      with_error_handling('submit draft appointment') do
        eps_appointment_service.create_draft_appointment(referral_id:)
      end
    end

    ##
    # Helper method to centralize error handling logic
    #
    # @param operation_name [String] Name of the operation being performed
    # @yield Block of code to execute with error handling
    # @return [Object] Result of the block if successful
    # @raise [DraftAppointmentServiceError] If an error occurs
    #
    def with_error_handling(operation_name)
      yield
    rescue VAOS::Exceptions::BackendServiceException, Eps::ServiceException => e
      detail = e.respond_to?(:detail) && e.detail.present? ? e.detail : e.message
      raise_service_error("Failed to #{operation_name}", detail)
    rescue Common::Client::Errors::ParsingError => e
      raise_service_error("Failed to #{operation_name}", 'Unable to parse response', status: :unprocessable_entity)
    rescue Common::Client::Errors::ClientError, Faraday::ClientError => e
      status = e.respond_to?(:response) && e.response ? e.response[:status] : :bad_request
      raise_service_error("Failed to #{operation_name}", e.message, status:)
    rescue Common::Exceptions::GatewayTimeout, Faraday::TimeoutError => e
      raise_service_error("Failed to #{operation_name}", 'Service timed out', status: :gateway_timeout)
    rescue Redis::BaseError => e
      raise_service_error("Failed to #{operation_name}", 'Cache service unavailable', :service_unavailable)
    rescue => e
      raise_service_error("Failed to #{operation_name}", e.message)
    end

    ##
    # Helper method to create and raise a DraftAppointmentServiceError
    #
    # @param message [String] The error message
    # @param detail [String] Additional error details
    # @param status [Symbol, Integer, nil] HTTP status code for the error response (defaults to :bad_gateway)
    # @raise [DraftAppointmentServiceError] The formatted error
    #
    def raise_service_error(message, detail, status = nil)
      raise DraftAppointmentServiceError.new(
        message,
        detail:,
        status:
      )
    end
  end
end
