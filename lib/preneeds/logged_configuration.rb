# frozen_string_literal: true

require 'common/client/middleware/logging'

module Preneeds
  # (see Preneeds::Configuration)
  # The difference between this configuration and it's parent class is the addition of the :logging middleware.
  # It is used for logging full requests and responses to assist EOAS engineers in troubleshooting.
  # This class will be removed when the EOAS service issues are resolved.
  #
  class LoggedConfiguration < Configuration
    # Creates the a connection with middleware for mapping errors, parsing XML, and adding breakers functionality.
    # The difference between this method and it's parent class' definition is the
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      path = Preneeds::Configuration.url
      @faraday ||= Faraday.new(
        path, headers: base_request_headers, request: request_options, ssl: { verify: false }
      ) do |conn|
        conn.use :breakers

        conn.options.timeout = TIMEOUT

        conn.request :soap_headers

        conn.response :preneeds_parser
        conn.response :soap_parser
        conn.response :eoas_xml_errors
        conn.response :clean_response
        conn.use :logging, 'PreneedsBurial' # Refactor as response middleware?
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
