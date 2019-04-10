# frozen_string_literal: true

require 'common/client/concerns/monitoring'

module Appeals
  ##
  # Proxy Service for Appeals Caseflow.
  #
  # @example Create a service and fetching appeals for a user
  #   appeals_response = Appeals::Service.new.get_appeals(user)
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Monitoring

    configuration Appeals::Configuration

    STATSD_KEY_PREFIX = 'api.appeals'

    ##
    # Returns appeals data for a user by their SSN.
    #
    # @param user [User] The user object, usually the `@current_user` from a controller.
    # @param additional_headers [Hash] Any additional HTTP headers you want to include in the request.
    # @return [Appeals::Responses::Appeals] Response object that includes the body.
    #
    def get_appeals(user, additional_headers = {})
      with_monitoring do
        response = perform(:get, '/api/v2/appeals', {}, request_headers(user, additional_headers))
        Appeals::Responses::Appeals.new(response.body, response.status)
      end
    end

    ##
    # Pings the Appeals Status health check endpoint.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def healthcheck
      with_monitoring do
        perform(:get, '/health-check', nil)
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
