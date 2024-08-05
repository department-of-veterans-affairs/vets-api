# frozen_string_literal: true

require 'common/client/configuration/rest'

module SearchTypeahead
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 2
    self.open_timeout = 2

    def base_path
      "#{Settings.search_typeahead.url}/suggestions"
    end

    def service_name
      'SearchTypeahead'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
