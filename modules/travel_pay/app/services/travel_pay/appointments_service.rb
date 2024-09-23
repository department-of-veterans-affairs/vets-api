# frozen_string_literal: true

module TravelPay
  class AppointmentsService
    def get_appointments_by_date(veis_token, btsss_token, params = {})
      faraday_response = client.get_all_appointments(veis_token, btsss_token, { 'excludeWithClaims' => true })
      raw_appointments = faraday_response.body['data'].deep_dup

      appointments = filter_by_date(params['appt_datetime'], raw_appointments)

      {
        data: appointments || []
      }
    end

    private

    def filter_by_date(date_string, appointments)
      if date_string.present?

        appointments.filter do |appointment|
          appointment['appointmentDateTime'].nil? &&
            date_string == appointment['appointmentDateTime']
        end
      end
    rescue Date::Error => e
      Rails.logger.debug(message: "#{e}. Unable to find appointments with date (given: #{date_string}).")
    end

    def client
      TravelPay::AppointmentsClient.new
    end
  end
end
