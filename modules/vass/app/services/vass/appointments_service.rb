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
    rescue Vass::ServiceException => e
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
    rescue Vass::ServiceException => e
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
    rescue Vass::ServiceException => e
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
    rescue Vass::ServiceException => e
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
    rescue Vass::ServiceException => e
      handle_error(e, 'get_appointments')
    end

    ##
    # Retrieves veteran information.
    #
    # @param veteran_id [String] Veteran ID in VASS system
    #
    # @return [Hash] Veteran data including name, contact info
    #
    # @example
    #   service.get_veteran_info(veteran_id: 'vet-123')
    #
    def get_veteran_info(veteran_id:)
      response = client.get_veteran(
        edipi:,
        veteran_id:
      )

      parse_response(response)
    rescue Vass::ServiceException => e
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
    rescue Vass::ServiceException => e
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
        if error.original_status == 401
          raise Vass::Errors::AuthenticationError, 'Authentication failed'
        elsif error.original_status == 404
          raise Vass::Errors::NotFoundError, 'Resource not found'
        else
          raise Vass::Errors::VassApiError, "VASS API error: #{error.class.name}"
        end
      else
        raise Vass::Errors::ServiceError, "Service error in #{method_name}: #{error.class.name}"
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
  end
end
