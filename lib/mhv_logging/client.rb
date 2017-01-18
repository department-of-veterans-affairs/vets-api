# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/concerns/verbose_logging'
require 'rx/configuration'
require 'rx/client_session'

# NOTE: This client uses the exact same configuration and client session
# as Rx does. It is the same server, but we're building it as a separate client
# for better separation of concerns since it can be invoked when using secure messaging

module MHVLogging
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient
    include Common::Client::VerboseLogging

    configuration Rx::Configuration
    client_session Rx::ClientSession

    def auditlogin
      body = { isSuccessful: true, activityDetails: 'Signed in Vets.gov' }
      perform(:post, 'activity/auditlogin', body, token_headers)
    end

    def auditlogout
      body = { isSuccessful: true, activityDetails: 'Signed out Vets.gov' }
      perform(:post, 'activity/auditlogout', body, token_headers)
    end

    private

    # Override connection in superclass because we don't want breakers for this client
    def connection
      @connection ||=
        Faraday.new(config.base_path, headers: config.base_request_headers, request: config.request_options) do |conn|
          conn.request :json

          # Uncomment this if you want curl command equivalent or response output to log
          # log_curl_and_response_ouput

          conn.response :snakecase
          conn.response :raise_error, error_prefix: 'MHV'
          conn.response :mhv_errors
          conn.response :json_parser
          conn.adapter Faraday.default_adapter
        end
    end
  end
end
