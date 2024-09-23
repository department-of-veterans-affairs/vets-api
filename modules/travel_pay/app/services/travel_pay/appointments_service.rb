# frozen_string_literal: true

module TravelPay
  class AppointmentsService
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
    def get_appointment_by_date_time(veis_token, btsss_token, params = {})
      faraday_response = client.get_all_appointments(veis_token, btsss_token, { 'excludeWithClaims' => true })
      raw_appointments = faraday_response.body['data'].deep_dup

      appointment = find_by_date_time(params['appt_datetime'], raw_appointments)

      {
        data: appointment
      }
    end

    private

    def find_by_date_time(date_string, appointments)
      if date_string.present?

        appointments.find do |appt|
          date_string == appt['appointmentDateTime']
        end
      end
    rescue Date::Error => e
      Rails.logger.debug(message: "#{e}. Unable to find appointment with provided date-time (given: #{date_string}).")
    end

    def client
      TravelPay::AppointmentsClient.new
    end
  end
end
