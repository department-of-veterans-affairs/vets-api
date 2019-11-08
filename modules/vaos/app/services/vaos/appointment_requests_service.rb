# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class AppointmentRequestsService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    attr_accessor :user

    STATSD_KEY_PREFIX = 'api.vaos'

    def self.for_user(user)
      rs = VAOS::AppointmentRequestsService.new
      rs.user = user
      rs
    end

    def get_requests(start_date = nil, end_date = nil)
      with_monitoring do
        response = perform(:get, get_appointment_requests_url(start_date, end_date), headers(user))

        {
          data: deserialize(response.body),
          meta: pagination
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def deserialize(json_hash)
      json_hash[:appointment_requests].map { |request| OpenStruct.new(request) }
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def get_appointment_requests_url(start_date = nil, end_date = nil)
      url = '/var/VeteranAppointmentRequestService/v4/rest/appointment-service'
      url += "/patient/ICN/#{user.icn}/appointments"
      url += get_date_url(start_date, end_date).empty? ? '' : "?#{get_date_url(start_date, end_date).to_query}"
      url
    end

    def get_date_url(start_date, end_date)
      { startDate: date_format(start_date), endDate: date_format(end_date) }
    end

    def date_format(date)
      date&.strftime('%Y-%m-%dT%TZ')
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
