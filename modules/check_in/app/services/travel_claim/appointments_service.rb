# frozen_string_literal: true

module TravelClaim
  ##
  # Service for orchestrating Travel Claim appointment operations.
  #
  # Coordinates between AuthManager for tokens and AppointmentsClient for HTTP requests.
  # Expects AuthManager to be provided by an orchestrator service.
  #
  class AppointmentsService
    include SentryLogging

    # @!attribute [r] auth_manager
    #   @return [TravelClaim::AuthManager] Authentication manager for token operations
    # @!attribute [r] check_in_session
    #   @return [CheckIn::V2::Session, nil] Optional check-in session for patient context
    attr_reader :auth_manager, :check_in_session

    ##
    # Initializes the appointments service with dependencies.
    #
    # @param opts [Hash] Options hash
    # @option opts [CheckIn::V2::Session] :check_in_session Check-in session for patient context
    # @option opts [CheckIn::V2::Session] :check_in Alias for :check_in_session (backward compatibility)
    # @option opts [TravelClaim::AuthManager] :auth_manager Authentication manager (provided by orchestrator)
    #
    def initialize(opts = {})
      @check_in_session = opts[:check_in_session] || opts[:check_in]
      @auth_manager = opts[:auth_manager]
      @client = AppointmentsClient.new
    end

    ##
    # Finds or creates an appointment in the Travel Claim system.
    #
    # This method validates the input parameters, obtains fresh authentication tokens,
    # and delegates to the AppointmentsClient to make the actual API request. The
    # correlation_id is passed through to maintain request tracing across the
    # orchestrator's 4-endpoint flow.
    #
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier
    # @param correlation_id [String] Request correlation ID for tracing across API calls
    # @return [Hash] Hash containing appointment data: { data: Hash }
    # @raise [ArgumentError] If appointment_date_time is invalid or nil
    # @raise [Common::Exceptions::BackendServiceException] If the API request fails
    #
    def find_or_create_appointment(appointment_date_time:, facility_id:, correlation_id:)
      validate_appointment_date_time(appointment_date_time)
      try_parse_date(appointment_date_time)

      tokens = auth_manager.request_new_tokens
      faraday_response = make_appointment_request(tokens, appointment_date_time:, facility_id:, correlation_id:)
      appointments = faraday_response.body['data']

      {
        # this returns an array of matching appointments - just return the first one
        data: appointments&.first
      }
    rescue ArgumentError => e
      handle_argument_error(e, appointment_date_time)
    rescue => e
      handle_general_error(e)
    end

    private

    def validate_appointment_date_time(appointment_date_time)
      if appointment_date_time.nil?
        Rails.logger.error(message: 'Invalid appointment time provided (appointment time cannot be nil).')
        raise ArgumentError, 'Invalid appointment time provided (appointment time cannot be nil).'
      end
    end

    def patient_icn
      @patient_icn ||= redis_client.icn(uuid: check_in_session.uuid) if check_in_session
    end

    def redis_client
      @redis_client ||= TravelClaim::RedisClient.build
    end

    def make_appointment_request(tokens, appointment_date_time:, facility_id:, correlation_id:)
      @client.find_or_create_appointment(
        tokens:,
        appointment_date_time:,
        facility_id:,
        patient_icn:,
        correlation_id:
      )
    end

    def handle_argument_error(error, appointment_date_time)
      Rails.logger.error(message: "#{error} Invalid appointment time provided (given: #{appointment_date_time}).")
      raise ArgumentError, "#{error} Invalid appointment time provided (given: #{appointment_date_time})."
    end

    def handle_general_error(error)
      error_body = error.respond_to?(:original_body) ? error.original_body : error.message
      log_message_to_sentry(error_body, :error,
                            { uuid: check_in_session&.uuid },
                            { external_service: 'BTSSS-API', team: 'check-in' })
      raise error
    end

    ##
    # Attempts to parse a datetime value into a Time object.
    #
    # @param datetime [String, Time, Date, nil] Datetime value to parse
    # @return [Time] Parsed time object
    # @raise [ArgumentError] If datetime is nil or cannot be parsed
    #
    def try_parse_date(datetime)
      raise ArgumentError, 'Provided datetime is nil.' if datetime.nil?

      return datetime.to_time if datetime.is_a?(Time) || datetime.is_a?(Date)

      # Disabled Rails/Timezone rule because we don't care about the tz in this dojo.
      # If we parse it any other 'recommended' way, the time will be converted based
      # on the timezone, and the datetimes won't match
      Time.parse(datetime) if datetime.is_a? String # rubocop:disable Rails/TimeZone
    end
  end
end
