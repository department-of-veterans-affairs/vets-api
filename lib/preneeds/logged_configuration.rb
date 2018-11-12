# frozen_string_literal: true

require 'common/client/middleware/logging'

module Preneeds
  class LoggedConfiguration < Configuration
    def connection
      path = Preneeds::Configuration.url
      @faraday ||= Faraday.new(
        path, headers: base_request_headers, request: request_options, ssl: { verify: false }
      ) do |conn|
        conn.options.timeout = TIMEOUT

        conn.request :soap_headers

        conn.response :preneeds_parser
        conn.response :soap_parser
        conn.response :eoas_xml_errors
        conn.response :clean_response

        conn.use :breakers # FIXME: breakers must appear first, to work correctly.
        conn.use :logging, 'PreneedsBurial' # FIXME: `use` middleware should appear (above `request` middleware).
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
