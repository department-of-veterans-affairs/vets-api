# frozen_string_literal: true

module TravelPay
  class AppointmentsService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    ##
    # gets all appointments and finds the singular BTSSS appointment that matches the provided datetime
    # @params: datetime string ('2024-01-01T12:45:34.465Z')
    #
    # @return {
    # 'id' => 'string',
    # 'appointmentSource' => 'string',
    # 'appointmentDateTime' => 'string',
    # 'appointmentName' => 'string',
    # 'appointmentType' => 'string',
    # 'facilityName' => 'string',
    # 'serviceConnectedDisability' => int,
    # 'currentStatus' => 'string',
    # 'appointmentStatus' => 'string',
    # 'externalAppointmentId' => 'string',
    # 'associatedClaimId' => string,
    # 'associatedClaimNumber' => string,
    # 'isCompleted' => boolean,
    # }
    #
    #
    def get_appointment_by_date_time(params = {})
      @auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_all_appointments(veis_token, btsss_token, { 'excludeWithClaims' => true })
      raw_appointments = faraday_response.body['data'].deep_dup
      appointment = find_by_date_time(params['appt_datetime'], raw_appointments)

      {
        data: appointment
      }
    end

    private

    def find_by_date_time(date_string, appointments)
      if date_string.nil?
        Rails.logger.error(message: 'Invalid appointment time provided (appointment time cannot be nil).')
        raise ArgumentError, message: 'Invalid appointment time provided (appointment time cannot be nil).'
      elsif date_string.present?
        parsed_date_time = DateUtils.strip_timezone(date_string)
        appointments.find do |appt|
          begin
            parsed_appt_time = DateUtils.strip_timezone(appt['appointmentDateTime'])
          rescue TravelPay::InvalidComparableError => e
            Rails.logger.warn("#{e} Appointment Datetime was nil")
          end
          !appt['appointmentDateTime'].nil? && parsed_date_time.eql?(parsed_appt_time)
        end
      end
    rescue ArgumentError => e
      Rails.logger.error(message: "#{e} Invalid appointment time provided (given: #{date_string}).")
      raise ArgumentError, "#{e} Invalid appointment time provided (given: #{date_string})."
    end

    def client
      TravelPay::AppointmentsClient.new
    end
  end
end
