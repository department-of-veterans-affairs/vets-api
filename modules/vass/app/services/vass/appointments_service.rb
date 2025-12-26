# frozen_string_literal: true

module Vass
  ##
  # Service class for managing VASS appointment scheduling operations.
  #
  # This service wraps the {Vass::Client} to provide business logic for appointment
  # management, including availability checks, appointment creation/cancellation,
  # and veteran information retrieval.
  #
  # @example Create a service and check availability
  #   service = Vass::AppointmentsService.build(edipi: '1234567890')
  #   availability = service.get_availability(
  #     start_date: Time.zone.now,
  #     end_date: Time.zone.now + 7.days,
  #     veteran_id: 'vet-123'
  #   )
  #
  # @!attribute [r] edipi
  #   @return [String] Veteran EDIPI
  # @!attribute [r] correlation_id
  #   @return [String] Correlation ID for request tracing
  # @!attribute [r] client
  #   @return [Vass::Client] VASS API client instance
  #
  class AppointmentsService
    attr_reader :edipi, :correlation_id, :client

    ##
    # Builds an AppointmentsService instance.
    #
    # @param opts [Hash] options to create the service
    # @option opts [String] :edipi Veteran EDIPI (required)
    # @option opts [String] :correlation_id Correlation ID for request tracing (optional)
    #
    # @return [Vass::AppointmentsService] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    ##
    # Initializes a new AppointmentsService.
    #
    # @param opts [Hash] options to create the service
    # @option opts [String] :edipi Veteran EDIPI (required)
    # @option opts [String] :correlation_id Correlation ID for request tracing (optional)
    #
    def initialize(opts = {})
      @edipi = opts[:edipi]
      @correlation_id = opts[:correlation_id] || SecureRandom.uuid
      @client = Vass::Client.new(correlation_id: @correlation_id)
    end

    ##
    # Retrieves appointment availability for a veteran.
    #
    # @param start_date [Time, String] Start date/time for availability search
    # @param end_date [Time, String] End date/time for availability search
    # @param veteran_id [String] Veteran ID in VASS system
    #
    # @return [Hash] Availability data with time slots
    #
    # @example
    #   service.get_availability(
    #     start_date: Time.zone.now,
    #     end_date: Time.zone.now + 7.days,
    #     veteran_id: 'vet-123'
    #   )
    #
    def get_availability(start_date:, end_date:, veteran_id:)
      availability_request = {
        correlationId: correlation_id,
        veteranId: veteran_id,
        dtStartUtc: format_datetime(start_date),
        dtEndUtc: format_datetime(end_date)
      }

      response = client.get_appointment_availability(
        edipi:,
        availability_request:
      )

      parse_response(response)
    rescue Vass::Errors::VassApiError, Vass::Errors::ServiceError,
           Common::Exceptions::BackendServiceException => e
      handle_error(e, 'get_availability')
    end

    ##
    # Creates a new appointment for a veteran.
    #
    # @param appointment_params [Hash] Appointment parameters
    # @option appointment_params [String] :veteran_id Veteran ID
    # @option appointment_params [Time, String] :time_start_utc Appointment start time
    # @option appointment_params [Time, String] :time_end_utc Appointment end time
    # @option appointment_params [String] :appointment_id Appointment ID (optional)
    # @option appointment_params [Array<String>] :selected_agent_skills Selected agent skill IDs
    #
    # @return [Hash] Created appointment data with appointment ID
    #
    # @example
    #   service.save_appointment(
    #     appointment_params: {
    #       veteran_id: 'vet-123',
    #       time_start_utc: Time.zone.now + 1.day,
    #       time_end_utc: Time.zone.now + 1.day + 30.minutes,
    #       selected_agent_skills: ['skill-1', 'skill-2']
    #     }
    #   )
    #
    def save_appointment(appointment_params:)
      appointment_data = {
        correlationId: correlation_id,
        veteranId: appointment_params[:veteran_id],
        timeStartUTC: format_datetime(appointment_params[:time_start_utc]),
        timeEndUTC: format_datetime(appointment_params[:time_end_utc]),
        appointmentId: appointment_params[:appointment_id],
        selectedAgentSkills: appointment_params[:selected_agent_skills]
      }.compact

      response = client.save_appointment(
        edipi:,
        appointment_data:
      )

      parse_response(response)
    rescue Vass::ServiceException,
           Common::Exceptions::GatewayTimeout,
           Common::Client::Errors::ClientError => e
      handle_error(e, 'save_appointment')
    end

    ##
    # Cancels an existing appointment.
    #
    # @param appointment_id [String] Appointment ID to cancel
    #
    # @return [Hash] Cancellation confirmation
    #
    # @example
    #   service.cancel_appointment(appointment_id: 'appt-123')
    #
    def cancel_appointment(appointment_id:)
      response = client.cancel_appointment(
        edipi:,
        appointment_id:
      )

      parse_response(response)
    rescue Vass::ServiceException,
           Common::Exceptions::GatewayTimeout,
           Common::Client::Errors::ClientError => e
      handle_error(e, 'cancel_appointment')
    end

    ##
    # Retrieves a specific appointment.
    #
    # @param appointment_id [String] Appointment ID to retrieve
    #
    # @return [Hash] Appointment data
    #
    # @example
    #   service.get_appointment(appointment_id: 'appt-123')
    #
    def get_appointment(appointment_id:)
      response = client.get_veteran_appointment(
        edipi:,
        appointment_id:
      )

      parse_response(response)
    rescue Vass::ServiceException,
           Common::Exceptions::GatewayTimeout,
           Common::Client::Errors::ClientError => e
      handle_error(e, 'get_appointment')
    end

    ##
    # Retrieves all appointments for a veteran.
    #
    # @param veteran_id [String] Veteran ID in VASS system
    #
    # @return [Hash] List of appointments
    #
    # @example
    #   service.get_appointments(veteran_id: 'vet-123')
    #
    def get_appointments(veteran_id:)
      response = client.get_veteran_appointments(
        edipi:,
        veteran_id:
      )

      parse_response(response)
    rescue Vass::ServiceException,
           Common::Exceptions::GatewayTimeout,
           Common::Client::Errors::ClientError => e
      handle_error(e, 'get_appointments')
    end

    ##
    # Retrieves veteran information by veteran ID (UUID).
    #
    # This method can be called without EDIPI - the VASS API returns EDIPI in the response.
    # Used for OTC flow where we only have the UUID from the welcome email.
    #
    # @param veteran_id [String] Veteran ID (UUID) in VASS system
    #
    # @return [Hash] Veteran data including firstName, lastName, dateOfBirth, edipi, notificationEmail
    #
    # @raise [Vass::Errors::VassApiError] if VASS API call fails
    #
    # @example Basic usage
    #   service.get_veteran_info(veteran_id: 'da1e1a40-1e63-f011-bec2-001dd80351ea')
    #
    def get_veteran_info(veteran_id:)
      response = client.get_veteran(veteran_id:)
      veteran_data = parse_response(response)

      # Validate we have the required data structure
      unless veteran_data && veteran_data['success'] && veteran_data['data']
        raise Vass::Errors::VassApiError,
              veteran_data&.dig('message') || 'Unable to retrieve veteran information'
      end

      # Extract and add contact info for OTC flow
      contact_method, contact_value = extract_contact_info(veteran_data)
      unless contact_method && contact_value
        raise Vass::Errors::MissingContactInfoError, 'Veteran contact information not found'
      end

      veteran_data.merge(
        'contact_method' => contact_method,
        'contact_value' => contact_value
      )
    rescue Vass::Errors::MissingContactInfoError
      raise
    rescue Vass::ServiceException,
           Common::Exceptions::GatewayTimeout,
           Common::Client::Errors::ClientError => e
      handle_error(e, 'get_veteran_info')
    end

    ##
    # Retrieves available agent skills for appointment scheduling.
    #
    # @return [Hash] List of available agent skills
    #
    # @example
    #   service.get_agent_skills
    #
    def get_agent_skills
      response = client.get_agent_skills

      parse_response(response)
    rescue Vass::ServiceException,
           Common::Exceptions::GatewayTimeout,
           Common::Client::Errors::ClientError => e
      handle_error(e, 'get_agent_skills')
    end

    ##
    # Health check endpoint to verify authentication and service availability.
    #
    # Note: This method is currently not implemented as it requires direct access
    # to the client's perform method. If needed, add a public method to the client.
    #
    # @return [Hash] Whoami response data
    #
    # @example
    #   service.whoami
    #
    def whoami
      # Placeholder - implement when needed
      raise NotImplementedError, 'whoami endpoint not yet implemented in service layer'
    end

    private

    ##
    # Formats a date/time object to ISO8601 format for VASS API.
    #
    # @param datetime [Time, String, nil] DateTime to format
    # @return [String, nil] ISO8601 formatted datetime string, or nil if input is nil
    #
    def format_datetime(datetime)
      return nil if datetime.nil?
      return datetime if datetime.is_a?(String)

      datetime.utc.iso8601
    end

    ##
    # Parses the Faraday response and extracts the body.
    #
    # @param response [Faraday::Env] Faraday response object
    # @return [Hash] Parsed response body
    #
    def parse_response(response)
      response.body
    end

    ##
    # Handles errors from VASS API calls.
    #
    # @param error [Exception] The caught exception
    # @param method_name [String] Name of the method that raised the error
    #
    # @raise [Vass::Errors::VassApiError] For VASS API errors
    # @raise [Vass::Errors::AuthenticationError] For authentication errors
    # @raise [Vass::Errors::ServiceError] For other service errors
    #
    def handle_error(error, method_name)
      log_error(error, method_name)

      case error
      when Vass::ServiceException
        # VASS-specific service exceptions (inherits from BackendServiceException)
        if error.original_status == 401
          raise Vass::Errors::AuthenticationError, 'Authentication failed'
        elsif error.original_status == 404
          raise Vass::Errors::NotFoundError, 'Resource not found'
        else
          raise Vass::Errors::VassApiError, "VASS API error: #{error.original_status}"
        end
      when Common::Exceptions::GatewayTimeout
        # Timeout errors from Faraday or Ruby's Timeout
        raise Vass::Errors::ServiceError, "Request timeout in #{method_name}"
      when Common::Client::Errors::ParsingError
        # JSON parsing errors from malformed responses
        raise Vass::Errors::ServiceError, "Response parsing error in #{method_name}"
      when Common::Client::Errors::ClientError
        # Network/HTTP errors (connection failures, SSL errors, etc.)
        status = error.status || 'unknown'
        raise Vass::Errors::ServiceError, "HTTP error (#{status}) in #{method_name}"
      else
        # This should not be reached given our explicit rescue clauses
        raise Vass::Errors::ServiceError, "Unexpected error in #{method_name}: #{error.class.name}"
      end
    end

    ##
    # Logs error information without PHI.
    #
    # @param error [Exception] The caught exception
    # @param method_name [String] Name of the method that raised the error
    #
    def log_error(error, method_name)
      Rails.logger.error({
        service: 'vass_appointments_service',
        method: method_name,
        error_class: error.class.name,
        correlation_id:,
        timestamp: Time.current.iso8601
      }.to_json)
    end

    ##
    # Validates veteran identity by comparing request data with VASS response.
    #
    # @param veteran_data [Hash] Veteran data from VASS API
    # @param last_name [String] User-provided last name
    # @param date_of_birth [String] User-provided date of birth
    # @return [Boolean] true if identity matches
    #
    def validate_veteran_identity(veteran_data, last_name, date_of_birth)
      return false unless veteran_data && veteran_data['data']

      data = veteran_data['data']
      last_name_match = normalize_name(data['lastName']) == normalize_name(last_name)
      dob_match = normalize_vass_date(data['dateOfBirth']) == Date.parse(date_of_birth)

      last_name_match && dob_match
    end

    ##
    # Validates veteran identity and enriches data with contact info.
    #
    # @param veteran_data [Hash] Veteran data from VASS API
    # @param last_name [String] Veteran's last name for validation
    # @param date_of_birth [String] Veteran's date of birth for validation
    # @return [Hash] Enriched veteran data with contact_method and contact_value
    # @raise [Vass::Errors::VassApiError] if data is invalid
    # @raise [Vass::Errors::IdentityValidationError] if identity doesn't match
    # @raise [Vass::Errors::MissingContactInfoError] if no contact info available
    #
    def validate_and_enrich_veteran_data(veteran_data, last_name, date_of_birth)
      unless veteran_data && veteran_data['success'] && veteran_data['data']
        raise Vass::Errors::VassApiError,
              veteran_data&.dig('message') || 'Unable to retrieve veteran information'
      end

      unless validate_veteran_identity(veteran_data, last_name, date_of_birth)
        raise Vass::Errors::IdentityValidationError, 'Veteran identity could not be verified'
      end

      contact_method, contact_value = extract_contact_info(veteran_data)
      unless contact_method && contact_value
        raise Vass::Errors::MissingContactInfoError, 'Veteran contact information not found'
      end

      veteran_data.merge(
        'contact_method' => contact_method,
        'contact_value' => contact_value
      )
    end

    ##
    # Extracts contact method and value from VASS veteran data.
    #
    # Currently only supports email (SMS not supported for OTC flow).
    #
    # @param veteran_data [Hash] Veteran data from VASS API
    # @return [Array<String, String>, Array[nil, nil]] [contact_method, contact_value] or [nil, nil]
    #
    def extract_contact_info(veteran_data)
      return [nil, nil] unless veteran_data && veteran_data['data']

      data = veteran_data['data']
      email = data['notificationEmail']

      if email.present?
        ['email', email]
      else
        [nil, nil]
      end
    end

    ##
    # Normalizes name for comparison (uppercase, strip whitespace).
    #
    # @param name [String, nil] Name to normalize
    # @return [String] Normalized name
    #
    def normalize_name(name)
      name.to_s.upcase.strip
    end

    ##
    # Normalizes date from VASS API format (M/D/YYYY) to Date object for comparison.
    #
    # Attempts to parse using the expected VASS format (M/D/YYYY) first,
    # falling back to Date.parse for other formats. Logs a warning when
    # fallback is used to help identify data quality issues.
    #
    # @param date [String] Date string from VASS API (e.g., "1/15/1990")
    # @return [Date] Parsed date object
    #
    def normalize_vass_date(date)
      Date.strptime(date, '%m/%d/%Y')
    rescue ArgumentError, TypeError
      Rails.logger.warn({
        service: 'vass_appointments_service',
        action: 'date_format_fallback',
        message: 'VASS API date not in expected M/D/YYYY format, using Date.parse fallback',
        date_format: date.class.name,
        correlation_id:,
        timestamp: Time.current.iso8601
      }.to_json)
      Date.parse(date)
    end
  end
end
