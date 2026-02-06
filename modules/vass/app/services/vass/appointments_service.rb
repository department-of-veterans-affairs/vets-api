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
    include Vass::Logging

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
    # Gets appointment availability for the veteran's current cohort.
    #
    # @param veteran_id [String] Veteran ID in VASS system
    # @return [Hash] Result with status (:available_slots, :already_booked, :next_cohort, :no_cohorts) and data
    #
    def get_current_cohort_availability(veteran_id:)
      # 1. Get veteran appointments
      appointments_response = get_appointments(veteran_id:)
      appointments = appointments_response.dig('data', 'appointments') || []
      # 2. Find current cohort
      current_cohort = find_current_cohort(appointments)

      # 3. Determine availability status
      return handle_no_current_cohort(appointments) unless current_cohort

      if cohort_booked?(current_cohort)
        handle_booked_cohort(current_cohort)
      else
        handle_available_cohort(current_cohort, veteran_id)
      end
    rescue Vass::Errors::VassApiError, Vass::Errors::ServiceError,
           Common::Exceptions::BackendServiceException => e
      handle_error(e, 'get_current_cohort_availability')
    end

    ##
    # Retrieves veteran information by veteran ID (UUID).
    #
    # This method can be called without EDIPI - the VASS API returns EDIPI in the response.
    # Used for OTP flow where we only have the UUID from the welcome email.
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
      veteran_data = response.body

      # Extract and add contact info for OTP flow
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
    # @return [Hash] Response with success flag and agent skills data
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
      return unless datetime
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
        status = error.original_status
        raise Vass::Errors::AuthenticationError, 'Authentication failed' if status == 401
        raise Vass::Errors::NotFoundError, 'Resource not found' if status == 404

        raise Vass::Errors::VassApiError, "VASS API error: #{status}"
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
      log_vass_event(action: method_name, level: :error, error_class: error.class.name, correlation_id:)
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
      return false unless veteran_data

      data = veteran_data['data']
      return false unless data

      last_name_match = normalize_name(data['last_name']) == normalize_name(last_name)
      dob_match = normalize_vass_date(data['date_of_birth']) == Date.parse(date_of_birth)

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
    # Currently only supports email (SMS not supported for OTP flow).
    #
    # @param veteran_data [Hash] Veteran data from VASS API
    # @return [Array<String, String>, Array[nil, nil]] [contact_method, contact_value] or [nil, nil]
    #
    def extract_contact_info(veteran_data)
      return [nil, nil] unless veteran_data

      data = veteran_data['data']
      return [nil, nil] unless data

      email = data['notification_email']

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
    # Normalizes date from VASS API format (M/D/YYYY) to Date object.
    #
    # Parses the date using the expected VASS format (M/D/YYYY).
    # Raises ValidationError if the date cannot be parsed.
    #
    # @param date [String] Date string from VASS API (e.g., "1/15/1990")
    # @return [Date] Parsed date object
    # @raise [Vass::Errors::ValidationError] if date cannot be parsed
    #
    def normalize_vass_date(date)
      Date.strptime(date, '%m/%d/%Y')
    rescue ArgumentError, TypeError
      log_vass_event(action: 'date_parse_failed', level: :error, correlation_id:)
      raise Vass::Errors::ValidationError, 'Invalid date format from VASS API'
    end

    ##
    # Finds the cohort appointment containing the current date.
    #
    # @param appointments [Array<Hash>] Array of veteran appointments
    # @return [Hash, nil] Cohort appointment or nil if none match
    #
    def find_current_cohort(appointments)
      now = Time.current

      appointments.find do |appt|
        cohort_start_utc = appt['cohort_start_utc']
        cohort_end_utc = appt['cohort_end_utc']
        next unless cohort_start_utc && cohort_end_utc

        cohort_start = parse_utc_time(cohort_start_utc, field_name: 'cohort_start_utc')
        cohort_end = parse_utc_time(cohort_end_utc, field_name: 'cohort_end_utc')
        next unless cohort_start && cohort_end

        now.between?(cohort_start, cohort_end)
      end
    end

    ##
    # Checks if a cohort appointment is already booked.
    #
    # @param cohort [Hash] Cohort appointment
    # @return [Boolean] True if booked, false otherwise
    #
    def cohort_booked?(cohort)
      cohort['start_utc'].present? && cohort['end_utc'].present?
    end

    ##
    # Handles the case when the current cohort is already booked.
    #
    # @param cohort [Hash] Booked cohort appointment
    # @return [Hash] Result with status and booked appointment data
    #
    def handle_booked_cohort(cohort)
      {
        status: :already_booked,
        data: {
          appointment_id: cohort['appointment_id'],
          start_utc: cohort['start_utc'],
          end_utc: cohort['end_utc']
        }
      }
    end

    ##
    # Handles the case when the current cohort is unbooked.
    #
    # Fetches available time slots from VASS API for the cohort window.
    #
    # @param cohort [Hash] Unbooked cohort appointment
    # @param veteran_id [String] Veteran ID
    # @return [Hash] Result with status and available slots data
    #
    def handle_available_cohort(cohort, veteran_id)
      cohort_start_utc = cohort['cohort_start_utc']
      cohort_end_utc = cohort['cohort_end_utc']
      availability = get_availability(veteran_id:, start_date: cohort_start_utc, end_date: cohort_end_utc)
      slots = availability.dig('data', 'available_time_slots') || []
      filtered_slots = filter_available_slots(slots)
      return build_no_slots_available_response if filtered_slots.empty?

      {
        status: :available_slots,
        data: {
          appointment_id: cohort['appointment_id'],
          cohort: { cohort_start_utc:, cohort_end_utc: },
          available_slots: filtered_slots
        }
      }
    end

    ##
    # Filters appointment slots by capacity and date range.
    #
    # Only returns slots that:
    # - Have available capacity (capacity > 0)
    # - Fall within tomorrow to two weeks from tomorrow
    #
    # @param slots [Array<Hash>] Raw appointment slots from VASS API
    # @return [Array<Hash>] Filtered slots with only dtStartUtc and dtEndUtc
    #
    def filter_available_slots(slots)
      tomorrow = Time.current.beginning_of_day + 1.day
      two_weeks_out = tomorrow + 2.weeks

      slots
        .select { |slot| (slot['capacity'] || 0).positive? }
        .select { |slot| slot_within_date_range?(slot, tomorrow, two_weeks_out) }
        .map { |slot| { 'dtStartUtc' => slot['time_start_utc'], 'dtEndUtc' => slot['time_end_utc'] } }
    end

    ##
    # Checks if a slot falls within the specified date range.
    #
    # @param slot [Hash] Appointment slot with timeStartUTC
    # @param start_range [Time] Start of allowed date range
    # @param end_range [Time] End of allowed date range
    # @return [Boolean] True if slot is within range
    #
    def slot_within_date_range?(slot, start_range, end_range)
      time_start_utc = slot['time_start_utc']
      return false unless time_start_utc

      slot_time = parse_utc_time(time_start_utc, field_name: 'time_start_utc')
      return false unless slot_time

      slot_time >= start_range && slot_time <= end_range
    end

    ##
    # Handles the case when no current cohort exists.
    #
    # Finds the next upcoming cohort or returns no cohorts status.
    #
    # @param appointments [Array<Hash>] All veteran appointments
    # @return [Hash] Result with status and next cohort data or no cohorts message
    #
    def handle_no_current_cohort(appointments)
      next_cohort = find_next_cohort(appointments)

      next_cohort ? build_next_cohort_response(next_cohort) : build_no_cohorts_response
    end

    ##
    # Finds the next upcoming cohort appointment.
    #
    # @param appointments [Array<Hash>] All veteran appointments
    # @return [Hash, nil] Next cohort appointment or nil if none found
    #
    def find_next_cohort(appointments)
      now = Time.current

      future_appointments = appointments.filter_map do |appt|
        cohort_start_utc = appt['cohort_start_utc']
        next unless cohort_start_utc

        parsed_time = parse_utc_time(cohort_start_utc, field_name: 'cohort_start_utc')
        { appt:, parsed_time: } if parsed_time && parsed_time > now
      end

      return nil if future_appointments.empty?

      future_appointments.min_by { |entry| entry[:parsed_time] }&.dig(:appt)
    end

    ##
    # Builds response for next cohort scenario.
    #
    # @param cohort [Hash] Next cohort appointment
    # @return [Hash] Result with next cohort status and data
    #
    def build_next_cohort_response(cohort)
      cohort_start_utc = cohort['cohort_start_utc']
      cohort_end_utc = cohort['cohort_end_utc']

      {
        status: :next_cohort,
        data: {
          message: "Booking opens on #{cohort_start_utc}",
          next_cohort: {
            cohort_start_utc:,
            cohort_end_utc:
          }
        }
      }
    end

    ##
    # Builds response for no cohorts available scenario.
    #
    # @return [Hash] Result with no cohorts status and message
    #
    def build_no_cohorts_response
      {
        status: :no_cohorts,
        data: {
          message: 'Current date outside of appointment cohort date ranges'
        }
      }
    end

    ##
    # Builds response for no available slots scenario.
    #
    # @return [Hash] Result with no slots status and message
    #
    def build_no_slots_available_response
      {
        status: :no_slots_available,
        data: {
          message: 'No available appointment slots'
        }
      }
    end

    ##
    # Parses a timestamp string as UTC.
    #
    # @param time_string [String] UTC timestamp string
    # @param field_name [String] Name of the field being parsed (for error logging)
    # @return [Time, nil] Parsed UTC time or nil if invalid
    # @raise [Vass::Errors::VassApiError] if parsing fails
    #
    def parse_utc_time(time_string, field_name: 'timestamp')
      Time.parse(time_string).utc
    rescue ArgumentError, TypeError => e
      log_error(e, "parse_utc_time (field: #{field_name})")
      raise Vass::Errors::VassApiError, "Invalid date/time format in #{field_name} from VASS API"
    end
  end
end
