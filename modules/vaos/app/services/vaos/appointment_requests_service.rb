# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class AppointmentRequestsService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    attr_accessor :user

    STATSD_KEY_PREFIX = 'api.vaos'

    def self.for_user(user)
      rs = VAOS::AppointmentRequestsService.new
      rs.user = user
      rs
    end

    def get_requests(_start_date, _end_date, _pagination_params)
      with_monitoring do
        response = perform(:get, get_appointment_requests_url, headers(user))

        {
          data: response.body[:appointment_requests].map { |request| OpenStruct.new(request) },
          meta: pagination
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def get_appointment_requests_url
      url = '/var/VeteranAppointmentRequestService/v4/rest/appointment-service'
      url += "/patient/ICN/#{user.icn}/appointments"
      url
    end

    # TODO: find out if this api supports pagination and other parameters
    def pagination
      {
        pagination: {
          current_page: 0,
          per_page: 0,
          total_pages: 0,
          total_entries: 0
        }
      }
    end
  end
end
