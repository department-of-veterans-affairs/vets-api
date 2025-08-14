# frozen_string_literal: true

module TravelClaim
  class AppointmentsService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    ##
    # Find or create an appointment using the v3 API
    # @params:
    #  {
    #   appointment_date_time: datetime string ('2024-01-01T12:45:34.465Z'),
    #   facility_station_number: string (i.e. facilityId),
    #   appointment_name: string, **Optional - will default to 'Medical Appointment'
    #   appointment_type: string, 'CompensationAndPensionExamination' || 'Other'
    #   is_complete: boolean,
    #  }
    #
    # @return [Hash] with appointment data or raises error
    # {
    #   data: {
    #     'id' => 'string (UUID)',
    #     'appointmentDateTime' => 'string',
    #     'appointmentName' => 'string',
    #     'appointmentType' => 'string',
    #     'facilityId' => 'string (UUID)',
    #     'facilityName' => 'string',
    #     'isCompleted' => boolean,
    #     ... other fields
    #   }
    # }
    #
    def find_or_create_appointment(params = {})
      validate_params(params)
      appointment_data = fetch_appointment_from_api(params)
      { data: appointment_data }
    rescue ArgumentError => e
      handle_argument_error(e)
    rescue Faraday::TimeoutError
      handle_timeout_error
    rescue => e
      handle_general_error(e)
    end

    private

    def validate_params(params)
      validate_required_params(params)
      validate_appointment_datetime(params['appointment_date_time'])
    end

    def fetch_appointment_from_api(params)
      access_token = @auth_manager.authorize
      faraday_response = client.find_or_add(access_token, params)
      appointments = faraday_response.body['data']

      if appointments.blank?
        Rails.logger.error(message: 'No appointment returned from BTSSS API')
        raise Common::Exceptions::BackendServiceException.new(
          nil, {}, detail: 'Failed to find or create appointment'
        )
      end

      # v3 API returns an array of matching appointments - return the first one
      appointments.first
    end

    def handle_argument_error(error)
      Rails.logger.error(message: "Invalid appointment parameters: #{error.message}")
      raise Common::Exceptions::BadRequest, detail: error.message
    end

    def handle_timeout_error
      Rails.logger.error(message: 'BTSSS timeout error during appointment lookup')
      raise Common::Exceptions::GatewayTimeout, detail: 'Appointment service timeout'
    end

    def handle_general_error(error)
      Rails.logger.error(message: "Appointment service error: #{error.message}")
      raise Common::Exceptions::BackendServiceException.new(
        nil, {}, detail: 'Failed to find or create appointment'
      )
    end

    def validate_required_params(params)
      raise ArgumentError, 'appointment_date_time is required' if params['appointment_date_time'].blank?
      raise ArgumentError, 'facility_station_number is required' if params['facility_station_number'].blank?

      # v3 API requires appointmentName with min 5 chars
      appointment_name = params['appointment_name'] || 'Medical Appointment'
      raise ArgumentError, 'appointment_name must be at least 5 characters' if appointment_name.length < 5
    end

    def validate_appointment_datetime(datetime_string)
      return if datetime_string.blank? # Already handled in validate_required_params

      begin
        DateTime.parse(datetime_string)
      rescue Date::Error => e
        raise ArgumentError, "Invalid appointment datetime format: #{e.message}"
      end
    end

    def client
      @client ||= TravelClaim::AppointmentsClient.new
    end
  end
end
