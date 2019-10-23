# frozen_string_literal: true

module VAOS
  class AppointmentService < Common::Client::Base
    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_appointments(user)
      @user = user
      app_response = {}
      @errors = []
      config.parallel_connection.in_parallel do
        app_response[:va_appointments] = make_request(:get_va_appointments) do |response|
          response.body.dig(:data, :appointment_list)
        end
        app_response[:cc_appointments] = make_request(:get_cc_appointments) do |_response|
          # TODO(AJD): implement CC response parsing
          []
        end
      end
      app_response[:errors] = @errors
      app_response
    end

    private

    def make_request(endpoint)
      response = config.parallel_connection.get(
        endpoints[endpoint], nil, 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => token
      )
      yield(response)
    rescue Faraday::ClientError => e
      @errors << { endpoint: endpoint, status: e.response[:status], message: e.message }
      log_error(e, endpoint)
      increment_failure(endpoint, e)
      nil
    ensure
      increment_total(endpoint)
    end

    def log_error(error, endpoint)
      Raven.extra_context(message: error.message, url: endpoints[endpoint])
      log_exception_to_sentry(error, status: error.response[:status], body: error.response[:body])
    end

    def increment_failure(endpoint, error)
      tags = ["error:#{error.class}"]
      tags << "status:#{error.status}" if error.try(:status)
      StatsD.increment("#{STATSD_KEY_PREFIX}.#{endpoint}.fail", tags: tags)
    end

    def increment_total(endpoint)
      StatsD.increment("#{STATSD_KEY_PREFIX}.#{endpoint}.total")
    end

    def endpoints
      {
        get_va_appointments: "/appointments/v1/patients/#{@user.icn}/appointments"\
          "?startDate=#{start_date}&endDate=#{end_date}&useCache=false&pageSize=0",
        get_cc_appointments: '/VeteranAppointmentRequestService/v4/rest/direct-scheduling/'\
          "patient/ICN/#{@user.icn}/booked-cc-appointments"\
          "?startDate=#{start_date}&endDate=#{end_date}&useCache=false&pageSize=0"
      }
    end

    def start_date
      (Time.now.utc.beginning_of_day + 7.hours).strftime('%Y-%m-%dT%TZ')
    end

    def end_date
      (Time.now.utc.beginning_of_day + 8.hours + 4.months).strftime('%Y-%m-%dT%TZ')
    end

    def token
      @memoized_token ||= VAOS::JWT.new(@user).token
    end
  end
end
