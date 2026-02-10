# frozen_string_literal: true

module VAOS
  module V2
    ##
    # CreateEpsDraftAppointment - Command object for creating Community Care appointment drafts
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
    #   draft = CreateEpsDraftAppointment.call(current_user, referral_id, referral_consult_id)
    #   if draft.error
    #     # Handle error: draft.error[:message], draft.error[:status]
    #   else
    #     # Use success data: draft.id, draft.provider, draft.slots, draft.drive_time
    #   end
    #
    class CreateEpsDraftAppointment
      include VAOS::CommunityCareConstants

      REFERRAL_DRAFT_STATIONID_METRIC = "#{STATSD_PREFIX}.referral_draft_station_id.access".freeze
      PROVIDER_DRAFT_NETWORK_ID_METRIC = "#{STATSD_PREFIX}.provider_draft_network_id.access".freeze
      APPT_DRAFT_CREATION_SUCCESS_METRIC = "#{STATSD_PREFIX}.appointment_draft_creation.success".freeze
      APPT_DRAFT_CREATION_FAILURE_METRIC = "#{STATSD_PREFIX}.appointment_draft_creation.failure".freeze
      # Number of characters to log from PII fields for safety
      SAFE_LOG_LENGTH = 3

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
      # @!attribute [r] type_of_care
      #   @return [String, nil] The sanitized type of care from the referral (e.g., 'CARDIOLOGY'),
      #     or nil if not yet determined
      attr_reader :id, :provider, :slots, :drive_time, :error, :type_of_care

      ##
      # Class method to create and execute draft appointment creation
      #
      # @param current_user [User] The authenticated user
      # @param referral_id [String] The referral identifier
      # @param referral_consult_id [String] The referral consultation identifier
      # @return [CreateEpsDraftAppointment] Instance with populated attributes or error
      def self.call(current_user, referral_id, referral_consult_id)
        new(current_user, referral_id, referral_consult_id).call
      end

      ##
      # Initialize a new draft appointment instance
      #
      # Sets up the instance with initial state. Does not perform any API calls
      # or business logic - call #call to execute the draft creation workflow.
      #
      # @param current_user [User] The authenticated user requesting the appointment
      # @param referral_id [String] The unique referral identifier
      # @param referral_consult_id [String] The referral consultation identifier
      #
      # @return [EpsDraftAppointment] A new instance ready to execute
      def initialize(current_user, referral_id, referral_consult_id)
        @current_user = current_user
        @referral_id = referral_id
        @referral_consult_id = referral_consult_id
        @id = nil
        @provider = nil
        @slots = nil
        @drive_time = nil
        @error = nil
        @type_of_care = nil
      end

      ##
      # Execute the draft appointment creation process
      #
      # Performs validation, then orchestrates the complete draft appointment
      # creation workflow, including referral validation, provider lookup,
      # slot checking, and draft creation. Sets either success state or an
      # error with appropriate status. Logs metrics for success/failure.
      #
      # @return [CreateEpsDraftAppointment] self with populated attributes or error
      def call
        unless validate_params(@referral_id, @referral_consult_id)
          log_draft_creation_metric(APPT_DRAFT_CREATION_FAILURE_METRIC)
          return self
        end

        build_appointment_draft(@referral_id, @referral_consult_id)

        if @error
          log_draft_creation_metric(APPT_DRAFT_CREATION_FAILURE_METRIC)
        else
          log_draft_creation_metric(APPT_DRAFT_CREATION_SUCCESS_METRIC)
        end

        self
      rescue => e
        log_draft_creation_metric(APPT_DRAFT_CREATION_FAILURE_METRIC)
        raise e
      end

      ##
      # Returns the controller name from RequestStore for logging context
      #
      # @return [String, nil] The controller name or nil if not set
      #
      def controller_name
        RequestStore.store['controller_name']
      end

      ##
      # Returns the user's primary station number (first treatment facility ID) for logging context
      #
      # @param user [User] The user object (optional, will try to use @current_user if not provided)
      # @return [String, nil] The station number or nil if not available
      #
      def station_number(user = nil)
        user_obj = user || @current_user
        user_obj&.va_treatment_facility_ids&.first
      end

      ##
      # Returns the EPS trace ID from RequestStore
      #
      # @return [String, nil] The trace ID or nil if not set
      #
      def eps_trace_id
        RequestStore.store['eps_trace_id']
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
        @referral = get_and_validate_referral(referral_consult_id)
        return if @error

        validate_referral_not_used(referral_id)
        return if @error

        provider = get_and_validate_provider(@referral)
        return if @error

        draft = create_draft_appointment(referral_id)
        return if @error

        @drive_time = fetch_drive_times(provider) unless eps_appointment_service.config.mock_enabled?
        @slots = fetch_provider_slots(@referral, provider, draft.id)
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
          log_referral_validation_failure(referral, validation_result[:missing_attributes])
          return set_error(
            "Required referral data is missing or incomplete: #{validation_result[:missing_attributes]}",
            :unprocessable_entity
          )
        end

        # Store type_of_care for metrics
        @type_of_care = sanitize_log_value(referral&.category_of_care)

        log_referral_metrics(referral)
        referral
      rescue Redis::BaseError => e
        handle_redis_error(e)
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
          log_personal_information_error('eps_draft_existing_appointment_check_failed', {
                                           referral_number: referral_id,
                                           failure_reason: "Error checking existing appointments: #{check[:failures]}"
                                         })
          set_error("Error checking existing appointments: #{check[:failures]}", :bad_gateway)
        elsif check[:exists]
          log_personal_information_error('eps_draft_referral_already_used', {
                                           referral_number: referral_id,
                                           failure_reason: 'Referral is already used for an existing appointment'
                                         })
          set_error('No new appointment created: referral is already used', :unprocessable_entity)
        end
      end

      ##
      # Find and validate the healthcare provider from referral data
      #
      # Uses the referral's NPI, specialty, and facility address to locate the provider
      # through the EPS provider service. Validates that a provider was found.
      # Note: Provider search failures are logged in Eps::ProviderService, so we don't
      # duplicate that logging here.
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
      # Note: Errors from the EPS service are logged in Eps::AppointmentService
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
      # Checks for presence of required attributes including the selected NPI based on feature flags,
      # and validates date formats. Used to ensure referral data is complete before attempting
      # appointment creation.
      #
      # @param referral [OpenStruct, nil] The referral object to validate
      # @return [Hash] Validation result with :valid boolean and :missing_attributes details
      def validate_referral_data(referral)
        return { valid: false, missing_attributes: 'all required attributes' } if referral.nil?

        # Get the selected NPI based on feature flags
        selected_npi = referral.selected_npi_for_eps(@current_user)

        required_attributes = {
          'selected_provider_npi' => selected_npi,
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
      # Searches the EPS provider service using the referral's selected NPI (based on feature flags),
      # specialty, and treating facility address to locate the appropriate provider.
      #
      # @param referral [OpenStruct] The referral containing search criteria
      # @return [OpenStruct, nil] The found provider object, or nil if not found
      def find_provider(referral)
        selected_npi = referral.selected_npi_for_eps(@current_user)
        npi_source = referral.selected_npi_source(@current_user)

        # Log which NPI source is being used for EPS lookup
        log_npi_selection(selected_npi, npi_source, referral)

        eps_provider_service.search_provider_services(
          npi: selected_npi,
          specialty: referral.provider_specialty,
          address: referral.treating_facility_address,
          referral_number: referral.referral_number
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
        slots = eps_provider_service.get_provider_slots(
          provider.id,
          build_slot_params(referral, appointment_type_id, draft_appointment_id)
        )
        log_provider_slots_info(slots)
        slots
      rescue ArgumentError => e
        log_slot_fetch_error(e)
        nil
      end

      ##
      # Build parameters for provider slot request
      #
      # @param referral [OpenStruct] The referral containing date constraints
      # @param appointment_type_id [String] The appointment type ID
      # @param draft_appointment_id [String] The draft appointment ID
      # @return [Hash] Parameters for slot request
      def build_slot_params(referral, appointment_type_id, draft_appointment_id)
        {
          appointmentTypeId: appointment_type_id,
          startOnOrAfter: [Date.parse(referral.referral_date), Date.current].max.to_time(:utc).iso8601,
          startBefore: Date.parse(referral.expiration_date).to_time(:utc).iso8601,
          appointmentId: draft_appointment_id
        }
      end

      ##
      # Log error when fetching provider slots fails
      #
      # @param error [Exception] The error that occurred
      # @return [void]
      def log_slot_fetch_error(error)
        error_data = {
          error_class: error.class.name,
          **common_logging_context
        }
        Rails.logger.error("#{CC_APPOINTMENTS}: Error fetching provider slots", error_data)
      end

      ##
      # Logs information about retrieved provider slots
      #
      # @param slots [Array<Hash>] The retrieved provider slots
      # @return [void]
      def log_provider_slots_info(slots)
        Rails.logger.info(
          "#{CC_APPOINTMENTS}: Provider slots retrieved",
          {
            slots_count: slots&.length || 0,
            slots_available: slots&.any? || false
          }
        )
      end

      ##
      # Extract the first self-schedulable appointment type ID from provider
      #
      # Filters the provider's appointment types to find self-schedulable options
      # and returns the ID of the first available type. Raises BackendServiceException
      # if provider data is invalid or no self-schedulable types are available.
      #
      # Note: This is defensive validation. The provider should already have self-schedulable
      # types since it passed through Eps::ProviderService#filter_self_schedulable. However,
      # we validate again here to catch any data inconsistencies between the search and slot fetch.
      #
      # @param provider [OpenStruct] The provider containing appointment types
      # @return [String] The appointment type ID
      # @raise [Common::Exceptions::BackendServiceException] When appointment types are missing
      #   or no self-schedulable types are available
      def get_provider_appointment_type_id(provider)
        # Let external service BackendServiceExceptions bubble up naturally
        handle_missing_appointment_types_error if provider.appointment_types.blank?

        self_schedulable_types = provider.appointment_types.select { |apt| apt[:is_self_schedulable] == true }

        handle_missing_self_schedulable_types_error if self_schedulable_types.blank?

        self_schedulable_types.first[:id]
      end

      ##
      # Handles error when provider appointment types data is missing
      #
      # Logs the error with structured data and raises a BackendServiceException
      # when the provider object doesn't contain appointment types information.
      #
      # @raise [Common::Exceptions::BackendServiceException] When appointment types are missing
      # @return [void]
      #
      def handle_missing_appointment_types_error
        log_personal_information_error('eps_draft_appointment_types_missing', {
                                         referral_number: @referral&.referral_number,
                                         npi: @referral&.selected_npi_for_eps(@current_user),
                                         failure_reason: 'Provider appointment types data is not available'
                                       })
        error_data = {
          error_message: 'Provider appointment types data is not available',
          **common_logging_context
        }
        message = "#{CC_APPOINTMENTS}: Provider appointment types data is not available"
        Rails.logger.error(message, error_data)
        raise Common::Exceptions::BackendServiceException.new(
          'PROVIDER_APPOINTMENT_TYPES_MISSING',
          {},
          502,
          'Provider appointment types data is not available'
        )
      end

      ##
      # Handles error when no self-schedulable appointment types are available
      #
      # Logs the error with structured data and raises a BackendServiceException
      # when the provider has appointment types but none are self-schedulable.
      # Note: This should theoretically never happen since the EPS API filters providers
      # using isSelfSchedulable=true query parameter. If it does trigger, it indicates
      # a data consistency issue. PII logging is already handled by ProviderService.
      #
      # @raise [Common::Exceptions::BackendServiceException] When no self-schedulable types are available
      # @return [void]
      #
      def handle_missing_self_schedulable_types_error
        error_data = {
          error_message: 'No self-schedulable appointment types available for this provider',
          **common_logging_context
        }
        message = "#{CC_APPOINTMENTS}: No self-schedulable appointment types available for this provider"
        Rails.logger.error(message, error_data)
        raise Common::Exceptions::BackendServiceException.new(
          'PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING',
          {},
          502,
          'No self-schedulable appointment types available for this provider'
        )
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
        station_id = sanitize_log_value(referral.station_id)
        type_of_care = sanitize_log_value(referral.category_of_care)

        StatsD.increment(REFERRAL_DRAFT_STATIONID_METRIC, tags: [
                           COMMUNITY_CARE_SERVICE_TAG,
                           "referring_facility_code:#{referring_facility_code}",
                           "station_id:#{station_id}",
                           "type_of_care:#{type_of_care}"
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
                           tags: [COMMUNITY_CARE_SERVICE_TAG, "network_id:#{network_id}"])
        end
      end

      ##
      # Log draft creation success or failure metric with type_of_care
      #
      # @param metric [String] The metric name to log
      # @return [void]
      def log_draft_creation_metric(metric)
        type_of_care = @type_of_care || 'no_value'
        StatsD.increment(metric, tags: [COMMUNITY_CARE_SERVICE_TAG, "type_of_care:#{type_of_care}"])
      end

      ##
      # Log detailed error information when provider is not found
      #
      # Records comprehensive error details including provider search criteria
      # to assist with debugging provider lookup failures.
      #
      # @param referral [OpenStruct] The referral containing failed search criteria
      # @return [void] Logs error details to Rails logger
      def log_provider_not_found_error(_referral)
        error_data = {
          error_message: 'Provider not found while creating draft appointment',
          **common_logging_context
        }
        Rails.logger.error("#{CC_APPOINTMENTS}: Provider not found while creating draft appointment", error_data)
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

      ##
      # Logs which NPI source is being used for EPS provider lookup
      # Only logs last 3 characters of NPI for PII safety
      #
      # Logs comprehensive information about NPI selection including:
      # - Which NPI source was used (primary_care, referring, treating_root, or treating_nested)
      # - Last 3 characters of the selected NPI (for PII safety)
      # - Which feature flags are enabled
      # - Associated referral number (last 3 chars for PII safety)
      #
      # @param selected_npi [String, nil] The NPI that will be used for lookup (can be nil if no NPI available)
      # @param npi_source [Symbol] The source of the NPI (:primary_care, :referring, :treating_root, :treating_nested)
      # @param referral [OpenStruct] The referral object
      # @return [void]
      def log_npi_selection(selected_npi, npi_source, referral)
        referral_number_safe = if referral.referral_number.present?
                                 referral.referral_number.to_s.last(SAFE_LOG_LENGTH)
                               end

        log_data = {
          npi_source:,
          npi_last3: selected_npi.present? ? selected_npi.to_s.last(SAFE_LOG_LENGTH) : nil,
          npi_present: selected_npi.present?,
          primary_care_npi_present: referral.primary_care_provider_npi.present?,
          referring_npi_present: referral.referring_provider_npi.present?,
          treating_npi_present: referral.treating_provider_npi.present?,
          provider_npi_present: referral.provider_npi.present?,
          primary_care_npi_flag_enabled: Flipper.enabled?(:va_online_scheduling_use_primary_care_npi, @current_user),
          referring_npi_flag_enabled: Flipper.enabled?(:va_online_scheduling_use_referring_provider_npi, @current_user),
          referral_number_last3: referral_number_safe
        }.merge(common_logging_context)

        Rails.logger.info("#{CC_APPOINTMENTS}: EPS provider lookup using selected NPI", log_data)
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
        nil # Metric logging happens at end of initialize
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

      def common_logging_context
        {
          user_uuid: @current_user&.uuid,
          controller: controller_name,
          station_number: station_number(@current_user),
          eps_trace_id:
        }
      end

      ##
      # Log personal information errors to PersonalInformationLog
      #
      # Creates an encrypted log entry for errors involving sensitive data like
      # referral numbers and NPIs. Gracefully handles logging failures to prevent
      # disruption of the main business logic.
      #
      # @param error_class [String] The error classification identifier
      # @param data [Hash] The data to log (will be encrypted)
      # @return [void]
      def log_personal_information_error(error_class, data)
        # Use create (not create!) so logging failures don't break the main flow
        PersonalInformationLog.create(
          error_class:,
          data: {
            npi: data[:npi],
            referral_number: data[:referral_number],
            user_uuid: data[:user_uuid] || @current_user&.uuid,
            search_params: data[:search_params],
            failure_reason: data[:failure_reason]
          }.compact
        )
      end

      ##
      # Log referral validation failure with PII
      #
      # @param referral [OpenStruct] The referral that failed validation
      # @param missing_attributes [String] Description of missing attributes
      # @return [void]
      def log_referral_validation_failure(referral, missing_attributes)
        log_personal_information_error('eps_draft_referral_validation_failed', {
                                         referral_number: referral&.referral_number,
                                         npi: referral&.selected_npi_for_eps(@current_user),
                                         failure_reason: 'Required referral data is missing or incomplete: ' \
                                                         "#{missing_attributes}"
                                       })
      end

      ##
      # Handle Redis errors with logging
      #
      # @param error [Redis::BaseError] The Redis error
      # @return [void]
      # @raise [Redis::BaseError] Re-raises the error after logging
      def handle_redis_error(error)
        error_data = {
          error_class: error.class.name,
          **common_logging_context
        }
        Rails.logger.error("#{CC_APPOINTMENTS}: Redis error", error_data)
        raise # Re-raise to let initialize rescue block handle metric logging
      end
    end
  end
end
