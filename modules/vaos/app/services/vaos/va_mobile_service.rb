# frozen_string_literal: true

require 'common/client/concerns/monitoring'

module VAOS
  class VAMobileService < Common::Client::Base
    include Common::Client::Monitoring
    configuration VAOS::Configuration
    STATSD_KEY_PREFIX = 'api.va_mobile_service' unless const_defined?(:STATSD_KEY_PREFIX)

    def get_va_appointments(user, start_date:, end_date:)
      with_monitoring do
        response = perform(:get, patient_appointment_url(user, start_date, end_date), {})
        response.body.deep_symbolize_keys![:data].map { |appointment| VAOS::Appointment.new(appointment) }
      end
    end

    private

    def patient_appointment_url(user, start_date, end_date)
      "/appointments/v1/patients/#{user.icn}/appointments"\
      "?startDate=#{start_date}&endDate=#{end_date}&useCache=false&pageSize=0"
    end
  end
end
