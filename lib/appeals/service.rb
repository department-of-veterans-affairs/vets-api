# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/concerns/service_errors'
require 'appeals_status/responses/get_appeals_response'

module Appeals
  class Service < Common::Client::Base
    include Common::Client::Monitoring
    include Common::Client::ServiceErrors

    configuration Appeals::Configuration

    STATSD_KEY_PREFIX = 'api.appeals'

    def get_appeals(user)
      with_monitoring do
        response = perform(:get, '', {}, request_headers(user))
        Appeals::Responses::Appeals.new(response.body, response.status)
      end
    rescue Common::Client::Errors::ClientError => error
      handle_service_error(error)
    end

    private

    def request_headers(user)
      {
        'ssn' => user.ssn,
        'Authorization' => "Token token=#{Settings.appeals.app_token}"
      }
    end
  end
end
