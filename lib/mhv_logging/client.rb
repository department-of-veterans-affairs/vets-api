# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/middleware/response/mhv_xml_html_errors'
require 'rx/configuration'
require 'rx/client_session'

# NOTE: This client uses the exact same configuration and client session
# as Rx does. It is the same server, but we're building it as a separate client
# for better separation of concerns since it can be invoked when using secure messaging

module MHVLogging
  # Core class responsible for api interface operations
  class MHVLoggingServiceException < Common::Exceptions::BackendServiceException; end
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration Rx::Configuration
    client_session Rx::ClientSession
    use_service_exception MHVLoggingServiceException

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
          # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
          # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

          conn.response :snakecase
          conn.response :raise_error, error_prefix: 'MHV'
          conn.response :mhv_errors
          conn.response :mhv_xml_html_errors
          conn.response :json_parser
          conn.adapter Faraday.default_adapter
        end
    end
  end
end
