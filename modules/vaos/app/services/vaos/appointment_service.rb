# frozen_string_literal: true
require_relative '../vaos/concerns/headers'

module VAOS
  class AppointmentService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_va_appointments(user, start_date, end_date)
      with_monitoring do
        url = get_va_appointments_url(user.icn, start_date, end_date)
        response = perform(:get, url, headers(user))
        {
          data: response.body.dig(:data, :appointment_list),
          meta: nil
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    def get_cc_appointments(user, start_date, end_date)
      with_monitoring do
        url = get_cc_appointments_url(user.icn, start_date, end_date)
        response = perform(:get, url, headers(user))
        {
          data: response.body[:booked_appointment_collections].first[:booked_cc_appointments],
          meta: nil
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def get_va_appointments_url(icn, start_date, end_date)
      "/appointments/v1/patients/#{icn}/appointments"\
          "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false&pageSize=0"
    end

    def get_cc_appointments_url(icn, start_date, end_date)
      '/VeteranAppointmentRequestService/v4/rest/direct-scheduling/'\
          "patient/ICN/#{icn}/booked-cc-appointments"\
          "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false&pageSize=0"
    end

    def date_format(date)
      date.strftime('%Y-%m-%dT%TZ')
    end
  end
end
