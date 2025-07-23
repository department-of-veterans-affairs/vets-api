# frozen_string_literal: true

module VAOS
  module V2
    ##
    # EpsDraftAppointment - Plain Old Ruby Object for creating Community Care appointment drafts
    #
    # This class encapsulates the business logic for creating a draft appointment through
    # the Enterprise Provider Service (EPS). It handles the complete workflow including:
    # - Validating referral data and ensuring it hasn't been used
    # - Finding and validating the healthcare provider
    # - Creating the draft appointment
    # - Fetching available appointment slots and drive time calculations
    #
    # The class follows an error-presence pattern where the presence of the +error+ attribute
    # indicates a failure, making success determination implicit. Business logic errors are
    # captured in +error+ with format { message: "...", status: :symbol }, while
    # BackendServiceException errors from external services bubble up naturally.
    #
    # @example Basic usage
    #   draft = EpsDraftAppointment.new(current_user, referral_id, referral_consult_id)
    #   if draft.error
    #     # Handle error: draft.error[:message], draft.error[:status]
    #   else
    #     # Use success data: draft.id, draft.provider, draft.slots, draft.drive_time
    #   end
    #
    class EpsDraftAppointment
      LOGGER_TAG = 'Community Care Appointments'
      REFERRAL_DRAFT_STATIONID_METRIC = 'api.vaos.referral_draft_station_id.access'
      PROVIDER_DRAFT_NETWORK_ID_METRIC = 'api.vaos.provider_draft_network_id.access'

      # @!attribute [r] id
      #   @return [String, nil] The ID of the created draft appointment, or nil if creation failed
      # @!attribute [r] provider
      #   @return [OpenStruct, nil] The provider information including location and appointment types,
      #     or nil if not found
      # @!attribute [r] slots
      #   @return [Array<Hash>, nil] Available appointment slots from the provider, or nil if unavailable
      # @!attribute [r] drive_time
      #   @return [Hash, nil] Drive time information from user's address to provider, or nil if unavailable
      # @!attribute [r] error
      #   @return [Hash, nil] Error information with :message and :status keys, or nil if successful
      attr_reader :id, :provider, :slots, :drive_time, :error

      ##
      # Initialize and execute the draft appointment creation process
      #
      # Sets up the object's initial state and delegates to the main orchestration
      # method. All validation and business logic is handled in build_appointment_draft.
      #
      # @param current_user [User] The authenticated user requesting the appointment
      # @param referral_id [String] The unique referral identifier
      # @param referral_consult_id [String] The referral consultation identifier
      #
      # @return [EpsDraftAppointment] A new instance with populated attributes or error
      def initialize(current_user, referral_id, referral_consult_id)
        @current_user = current_user
        @id = @provider = @slots = @drive_time = @error = nil

        return unless validate_params(referral_id, referral_consult_id)

        build_appointment_draft(referral_id, referral_consult_id)
      end

      private

      ##
      # Main orchestration method that builds the appointment draft
      #
      # Coordinates the entire process of creating a draft appointment by calling
      # validation and data gathering methods in the correct sequence. Uses early
      # returns when errors are encountered to avoid unnecessary processing.
      #
      # @param referral_id [String] The unique referral identifier
      # @param referral_consult_id [String] The referral consultation identifier
      # @return [void] Sets instance variables for success data or error state
      def build_appointment_draft(referral_id, referral_consult_id)
        referral = get_and_validate_referral(referral_consult_id)
        return if @error

        validate_referral_not_used(referral_id)
        return if @error

        provider = get_and_validate_provider(referral)
        return if @error

        draft = create_draft_appointment(referral_id)
        return if @error

        @drive_time = fetch_drive_times(provider) unless eps_appointment_service.config.mock_enabled?
        @slots = fetch_provider_slots(referral, provider, draft.id)
        @id = draft.id
        @provider = provider
      end

      ##
      # Validate initialization requirements including authentication and parameters
      #
      # Performs upfront validation of user authentication and required parameters
      # before any business logic processing begins.
      #
      # @param referral_id [String] The unique referral identifier
      # @param referral_consult_id [String] The referral consultation identifier
      # @return [Boolean] true if validation passed, false if validation failed (error set)
      def validate_params(referral_id, referral_consult_id)
        if @current_user.nil?
          set_error('User authentication required', :unauthorized)
          return false
        end

        missing_params = get_missing_parameters(referral_id, referral_consult_id, @current_user.icn)
        if missing_params.any?
          set_error("Missing required parameters: #{missing_params.join(', ')}", :bad_request)
          return false
        end

        true
      end

      ##
      # Identify which required parameters are missing or invalid
      #
      # Checks each required parameter and returns a list of the ones that are blank.
      # Used to provide specific error messages about which parameters are missing.
      #
      # @param referral_id [String, nil] The referral identifier to validate
      # @param referral_consult_id [String, nil] The consultation identifier to validate
      # @param user_icn [String, nil] The user's ICN to validate
      # @return [Array<String>] List of missing parameter names
      def get_missing_parameters(referral_id, referral_consult_id, user_icn)
        missing = []
        missing << 'referral_id' if referral_id.blank?
        missing << 'referral_consult_id' if referral_consult_id.blank?
        missing << 'user ICN' if user_icn.blank?
        missing
      end

      ##
      # Check if any required initialization parameters are missing or invalid
      #
      # Validates that all required parameters for appointment creation are present
      # and properly formatted. Used for upfront validation after authentication check.
      #
      # @param referral_id [String, nil] The referral identifier to validate
      # @param referral_consult_id [String, nil] The consultation identifier to validate
      # @param user_icn [String, nil] The user's ICN to validate
      # @return [Boolean] true if any parameters are invalid, false if all are valid
      def invalid_parameters?(referral_id, referral_consult_id, user_icn)
        referral_id.blank? || referral_consult_id.blank? || user_icn.blank?
      end

      # =============================================================================
      # ORCHESTRATION METHODS
      # =============================================================================

      ##
      # Retrieve and validate referral data from the CCRA service
      #
      # Fetches referral information and validates that all required fields are present
      # and properly formatted. Handles Redis connection errors gracefully.
      #
      # @param referral_consult_id [String] The referral consultation identifier
      # @return [OpenStruct, nil] The validated referral object, or nil if error occurred
      def get_and_validate_referral(referral_consult_id)
        referral = ccra_referral_service.get_referral(referral_consult_id, @current_user.icn)
        validation_result = validate_referral_data(referral)

        unless validation_result[:valid]
          return set_error(
            "Required referral data is missing or incomplete: #{validation_result[:missing_attributes]}",
            :unprocessable_entity
          )
        end

        log_referral_metrics(referral)
        referral
      rescue Redis::BaseError => e
        Rails.logger.error("#{LOGGER_TAG}: Redis error - #{e.class}: #{e.message}")
        set_error('Redis connection error', :bad_gateway)
      end

      ##
      # Validate that the referral has not already been used for an appointment
      #
      # Checks with the appointments service to ensure this referral hasn't already
      # been used to create an appointment, preventing duplicate appointments.
      #
      # @param referral_id [String] The referral identifier to check
      # @return [void] Sets error state if referral is already used or check fails
      def validate_referral_not_used(referral_id)
        check = appointments_service.referral_appointment_already_exists?(referral_id)
        if check[:error]
          set_error("Error checking existing appointments: #{check[:failures]}", :bad_gateway)
        elsif check[:exists]
          set_error('No new appointment created: referral is already used', :unprocessable_entity)
        end
      end

      ##
      # Find and validate the healthcare provider from referral data
      #
      # Uses the referral's NPI, specialty, and facility address to locate the provider
      # through the EPS provider service. Validates that a provider was found.
      #
      # @param referral [OpenStruct] The referral object containing provider search criteria
      # @return [OpenStruct, nil] The validated provider object, or nil if error occurred
      def get_and_validate_provider(referral)
        provider = find_provider(referral)
        if provider&.id.blank?
          log_provider_not_found_error(referral)
          return set_error('Provider not found', :not_found)
        end

        log_provider_metrics(provider)
        provider
      end

      ##
      # Create a draft appointment through the EPS service
      #
      # Calls the EPS appointment service to create a new draft appointment
      # and validates that the creation was successful.
      #
      # @param referral_id [String] The referral identifier for the appointment
      # @return [OpenStruct, nil] The created draft appointment object, or nil if error occurred
      def create_draft_appointment(referral_id)
        draft = eps_appointment_service.create_draft_appointment(referral_id:)
        return set_error('Could not create draft appointment', :unprocessable_entity) if draft.id.blank?

        draft
      end

      # =============================================================================
      # VALIDATION METHODS
      # =============================================================================

      ##
      # Validate that referral contains all required data with proper formatting
      #
      # Checks for presence of required attributes and validates date formats.
      # Used to ensure referral data is complete before attempting appointment creation.
      #
      # @param referral [OpenStruct, nil] The referral object to validate
      # @return [Hash] Validation result with :valid boolean and :missing_attributes details
      def validate_referral_data(referral)
        return { valid: false, missing_attributes: 'all required attributes' } if referral.nil?

        required_attributes = {
          'provider_npi' => referral.provider_npi,
          'referral_date' => referral.referral_date,
          'expiration_date' => referral.expiration_date
        }

        missing_attributes = required_attributes.select { |_, value| value.blank? }.keys
        return { valid: false, missing_attributes: missing_attributes.join(', ') } unless missing_attributes.empty?

        # Validate date formats
        begin
          Date.parse(referral.referral_date)
          Date.parse(referral.expiration_date)
        rescue ArgumentError
          return { valid: false, missing_attributes: 'invalid date format' }
        end

        { valid: true, missing_attributes: [] }
      end

      # =============================================================================
      # BUSINESS LOGIC METHODS
      # =============================================================================

      ##
      # Search for a healthcare provider using referral criteria
      #
      # Searches the EPS provider service using the referral's NPI, specialty,
      # and treating facility address to locate the appropriate provider.
      #
      # @param referral [OpenStruct] The referral containing search criteria
      # @return [OpenStruct, nil] The found provider object, or nil if not found
      def find_provider(referral)
        eps_provider_service.search_provider_services(
          npi: referral.provider_npi,
          specialty: referral.provider_specialty,
          address: referral.treating_facility_address
        )
      end

      ##
      # Fetch available appointment slots from the provider
      #
      # Retrieves available appointment slots within the referral's date range,
      # using the first self-schedulable appointment type available from the provider.
      #
      # @param referral [OpenStruct] The referral containing date constraints
      # @param provider [OpenStruct] The provider to get slots from
      # @param draft_appointment_id [String] The draft appointment ID for slot association
      # @return [Array<Hash>, nil] Available appointment slots, or nil if unavailable
      def fetch_provider_slots(referral, provider, draft_appointment_id)
        appointment_type_id = get_provider_appointment_type_id(provider)
        return nil if appointment_type_id.nil?

        eps_provider_service.get_provider_slots(
          provider.id,
          {
            appointmentTypeId: appointment_type_id,
            startOnOrAfter: [Date.parse(referral.referral_date), Date.current].max.to_time(:utc).iso8601,
            startBefore: Date.parse(referral.expiration_date).to_time(:utc).iso8601,
            appointmentId: draft_appointment_id
          }
        )
      rescue ArgumentError
        Rails.logger.error("#{LOGGER_TAG}: Error fetching provider slots")
        nil
      end

      ##
      # Extract the first self-schedulable appointment type ID from provider
      #
      # Filters the provider's appointment types to find self-schedulable options
      # and returns the ID of the first available type. Raises BackendServiceException
      # if provider data is invalid or no self-schedulable types are available.
      #
      # @param provider [OpenStruct] The provider containing appointment types
      # @return [String] The appointment type ID
      # @raise [Common::Exceptions::BackendServiceException] When appointment types are missing
      #   or no self-schedulable types are available
      def get_provider_appointment_type_id(provider)
        # Let external service BackendServiceExceptions bubble up naturally
        if provider.appointment_types.blank?
          Rails.logger.error("#{LOGGER_TAG}: Provider appointment types data is not available")
          raise Common::Exceptions::BackendServiceException.new(
            'PROVIDER_APPOINTMENT_TYPES_MISSING',
            {},
            502,
            'Provider appointment types data is not available'
          )
        end

        self_schedulable_types = provider.appointment_types.select { |apt| apt[:is_self_schedulable] == true }

        if self_schedulable_types.blank?
          Rails.logger.error("#{LOGGER_TAG}: No self-schedulable appointment types available for this provider")
          raise Common::Exceptions::BackendServiceException.new(
            'PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING',
            {},
            502,
            'No self-schedulable appointment types available for this provider'
          )
        end

        self_schedulable_types.first[:id]
      end

      ##
      # Calculate drive time from user's address to the provider
      #
      # Uses the user's residential address and provider's location to calculate
      # drive time via the EPS provider service. Returns nil if user address unavailable.
      #
      # @param provider [OpenStruct] The provider with location coordinates
      # @return [Hash, nil] Drive time information, or nil if user address unavailable
      def fetch_drive_times(provider)
        user_address = @current_user.vet360_contact_info&.residential_address
        return nil unless user_address&.latitude && user_address.longitude

        eps_provider_service.get_drive_times(
          destinations: {
            provider.id => {
              latitude: provider.location[:latitude],
              longitude: provider.location[:longitude]
            }
          },
          origin: { latitude: user_address.latitude, longitude: user_address.longitude }
        )
      end

      # =============================================================================
      # LOGGING AND METRICS
      # =============================================================================

      ##
      # Log metrics for referral fetch
      #
      # Records StatsD metrics with sanitized referring provider and referral provider IDs
      # for monitoring and analytics purposes.
      #
      # @param referral [OpenStruct, nil] The referral object containing provider information
      # @return [void] Logs metrics to StatsD
      def log_referral_metrics(referral)
        return if referral.nil?

        referring_facility_code = sanitize_log_value(referral.referring_facility_code)
        provider_npi = sanitize_log_value(referral.provider_npi)
        station_id = sanitize_log_value(referral.station_id)

        StatsD.increment(REFERRAL_DRAFT_STATIONID_METRIC, tags: [
                           'service:community_care_appointments',
                           "referring_facility_code:#{referring_facility_code}",
                           "provider_npi:#{provider_npi}",
                           "station_id:#{station_id}"
                         ])
      end

      ##
      # Log metrics for each provider network ID
      #
      # Records StatsD metrics for each network ID associated with the provider
      # to track usage across different provider networks.
      #
      # @param provider [OpenStruct, nil] The provider object containing network IDs
      # @return [void] Logs metrics to StatsD for each network ID
      def log_provider_metrics(provider)
        return if provider&.network_ids.blank?

        provider.network_ids.each do |network_id|
          StatsD.increment(PROVIDER_DRAFT_NETWORK_ID_METRIC,
                           tags: ['service:community_care_appointments', "network_id:#{network_id}"])
        end
      end

      ##
      # Log detailed error information when provider is not found
      #
      # Records comprehensive error details including provider search criteria
      # to assist with debugging provider lookup failures.
      #
      # @param referral [OpenStruct] The referral containing failed search criteria
      # @return [void] Logs error details to Rails logger
      def log_provider_not_found_error(referral)
        Rails.logger.error("#{LOGGER_TAG}: Provider not found while creating draft appointment.",
                           { provider_address: referral.treating_facility_address,
                             provider_npi: referral.provider_npi,
                             provider_specialty: referral.provider_specialty,
                             tag: LOGGER_TAG })
      end

      ##
      # Sanitize values for safe logging and metrics
      #
      # Replaces blank values with 'no_value' and removes whitespace from strings
      # to ensure consistent formatting in logs and metrics.
      #
      # @param value [String, nil] The value to sanitize
      # @return [String] The sanitized value safe for logging
      def sanitize_log_value(value)
        return 'no_value' if value.blank?

        value.to_s.gsub(/\s+/, '_')
      end

      # =============================================================================
      # HELPER METHODS & SERVICE INITIALIZATION
      # =============================================================================

      ##
      # Set error state and return nil for method chaining
      #
      # Helper method to DRY up error setting throughout the class. Sets the @error
      # instance variable and returns nil to enable early returns from methods.
      #
      # @param message [String] Human-readable error description
      # @param status [Symbol] HTTP status symbol (e.g., :bad_request, :not_found)
      # @return [nil] Always returns nil to support early return pattern
      def set_error(message, status)
        @error = { message:, status: }
        nil
      end

      ##
      # Lazy-initialize the CCRA referral service
      #
      # Creates and memoizes a CCRA referral service instance for the current user.
      # Used for retrieving referral data from the Community Care Referral API.
      #
      # @return [Ccra::ReferralService] The memoized CCRA referral service instance
      def ccra_referral_service
        @ccra_referral_service ||= Ccra::ReferralService.new(@current_user)
      end

      ##
      # Lazy-initialize the EPS appointment service
      #
      # Creates and memoizes an EPS appointment service instance for the current user.
      # Used for creating draft appointments through the Enterprise Provider Service.
      #
      # @return [Eps::AppointmentService] The memoized EPS appointment service instance
      def eps_appointment_service
        @eps_appointment_service ||= Eps::AppointmentService.new(@current_user)
      end

      ##
      # Lazy-initialize the EPS provider service
      #
      # Creates and memoizes an EPS provider service instance for the current user.
      # Used for provider searches, slot retrieval, and drive time calculations.
      #
      # @return [Eps::ProviderService] The memoized EPS provider service instance
      def eps_provider_service
        @eps_provider_service ||= Eps::ProviderService.new(@current_user)
      end

      ##
      # Lazy-initialize the VAOS appointments service
      #
      # Creates and memoizes a VAOS appointments service instance for the current user.
      # Used for checking if referrals have already been used for appointments.
      #
      # @return [VAOS::V2::AppointmentsService] The memoized VAOS appointments service instance
      def appointments_service
        @appointments_service ||= VAOS::V2::AppointmentsService.new(@current_user)
      end
    end
  end
end
