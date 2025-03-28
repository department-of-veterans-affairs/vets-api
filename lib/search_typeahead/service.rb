# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'search_typeahead/configuration'

module SearchTypeahead
  # This class builds a wrapper around Search.gov web suggestioms API.
  #
  # @see https://search.usa.gov/sites/7378/type_ahead_api_instructions
  #
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.search_typeahead'

    configuration SearchTypeahead::Configuration

    attr_reader :query

    def initialize(query)
      @query = query || ''
    end

    # GETs suggestion data from search.gov
    #
    def suggestions
      with_monitoring do
        Faraday.get(suggestions_url, query_params) do |req|
          req.options.timeout = 2
          req.options.open_timeout = 2
        end
      end
    rescue Faraday::TimeoutError
      build_error_response('The request timed out. Please try again.', 504)
    rescue Faraday::ConnectionFailed
      build_error_response('Unable to connect to the search service. Please try again later.', 502)
    rescue => e
      Rails.logger.error("SearchTypeahead Service error: #{e.message}")
      build_error_response('An unexpected error occurred.', 500)
    end

    private

    def suggestions_url
      config.base_path
    end

    # Required params [name, access_key, query]
    #
    # @see https://search.usa.gov/sites/7378/type_ahead_api_instructions
    #
    def query_params
      {
        name:,
        q: query,
        api_key:
      }
    end

    def name
      Settings.search_typeahead.name
    end

    def api_key
      Settings.search_typeahead.api_key
    end

    def build_error_response(message, status_code)
      OpenStruct.new(
        body: { error: message }.to_json,
        status: status_code
      )
    end
  end
end
