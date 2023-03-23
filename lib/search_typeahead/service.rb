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
      @query = query
    end

    # GETs suggestion data from search.gov
    #
    def suggestions
      with_monitoring do
        Faraday.get(suggestions_url, query_params)
      end
    rescue => e
      e
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
  end
end
