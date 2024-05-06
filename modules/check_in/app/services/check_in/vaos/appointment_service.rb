# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'
require 'memoist'

module CheckIn
  module VAOS
    class AppointmentService < CheckIn::VAOS::BaseService
      def get_appointments(start_date, end_date, statuses = nil)
        params = date_params(start_date, end_date)
                 .merge(status_params(statuses))
                 .compact

        with_monitoring do
          response = perform(:get, appointments_base_path, params, headers)
          response.body
        end
      end

      private

      def appointments_base_path
        "/vaos/v1/patients/#{patient_icn}/appointments"
      end

      def date_params(start_date, end_date)
        { start: date_format(start_date), end: date_format(end_date) }
      end

      def status_params(statuses)
        { statuses: }
      end

      def date_format(date)
        date.strftime('%Y-%m-%dT%TZ')
      end
    end
  end
end
