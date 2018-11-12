# frozen_string_literal: true

require 'common/client/concerns/monitoring'

module Appeals
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Monitoring

    configuration Appeals::Configuration

    STATSD_KEY_PREFIX = 'api.appeals'

    def get_appeals(user, additional_headers = {})
      with_monitoring do
        response = perform(:get, '', {}, request_headers(user, additional_headers))
        Appeals::Responses::Appeals.new(response.body, response.status)
      end
    end

    private

    def request_headers(user, additional_headers)
      {
        'ssn' => user.ssn,
        'Authorization' => "Token token=#{Settings.appeals.app_token}"
      }.merge(additional_headers)
    end
  end
end
