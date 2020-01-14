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
        response = perform(:get, get_request_url, date_params(start_date, end_date), headers(user))

        {
          data: deserialize(response.body),
          meta: pagination
        }
      end
    end

    def post_request(params)
      with_monitoring do
        validated_params = form_object(params).params
        response = perform(:post, post_request_url(params[:type]), validated_params, headers(user))

        {
          data: OpenStruct.new(filter_cc_appointment_data(response.body))
        }
      end
    end

    def put_request(id, params)
      with_monitoring do
        validated_params = form_object(params, id).params
        response = perform(:put, put_request_url(id), validated_params, headers(user))

        {
          data: OpenStruct.new(filter_cc_appointment_data(response.body))
        }
      end
    end

    private

    def get_request_url
      "/var/VeteranAppointmentRequestService/v4/rest/appointment-service/patient/ICN/#{user.icn}/appointments"
    end

    def put_request_url(id)
      post_request_url + "/system/var/id/#{id}"
    end

    def post_request_url(request_type = '')
      type = request_type&.upcase == 'CC' ? 'community-care-appointment' : 'appointments'
      "/var/VeteranAppointmentRequestService/v4/rest/appointment-service/patient/ICN/#{user.icn}/#{type}"
    end

    def form_object(params, id = nil)
      if params[:type]&.upcase == 'CC'
        VAOS::CCAppointmentRequestForm.new(user, params.merge(id: id))
      else
        VAOS::AppointmentRequestForm.new(user, params.merge(id: id))
      end
    end

    def deserialize(json_hash)
      json_hash[:appointment_requests].map do |request|
        filter_cc_appointment_data(request)
        OpenStruct.new(request)
      end
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def filter_cc_appointment_data(request)
      return request if request[:cc_appointment_request].nil?

      request[:cc_appointment_request].except!(
        :patient_identifier, :surrogate_identifier, :object_type, :link
      )
      request
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
