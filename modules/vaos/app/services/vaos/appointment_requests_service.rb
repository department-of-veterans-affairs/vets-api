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
        response = perform(:get, url, date_params(start_date, end_date), headers(user))

        {
          data: deserialize(response.body),
          meta: pagination
        }
      end
    end

    def post_request(request_object_body)
      with_monitoring do
        params = VAOS::AppointmentRequestForm.new(user, request_object_body).params
        response = perform(:post, url, params, headers(user))
        binding.pry
        {
          data: OpenStruct.new(response.body)
        }
      end
    end

    def put_request(request_object_body)
      with_monitoring do
        params = VAOS::AppointmentRequestForm.new(user, request_object_body).params
        response = perform(:put, url(id), params, headers(user))
        binding.pry
        {
          data: OpenStruct.new(response.body)
        }
      end
    end

    private

    def deserialize(json_hash)
      json_hash[:appointment_requests].map { |request| OpenStruct.new(request) }
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def url(id = nil)
      if id
        url + "/system/var/id/#{id}"
      else
        "/var/VeteranAppointmentRequestService/v4/rest/appointment-service/patient/ICN/#{user.icn}/appointments"
      end
    end

    def date_params(start_date, end_date)
      { startDate: date_format(start_date), endDate: date_format(end_date) }.compact
    end

    def date_format(date)
      date&.strftime('%m/%d/%Y')
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
