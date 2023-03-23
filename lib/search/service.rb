# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'search/response'
require 'search/configuration'

module Search
  # This class builds a wrapper around Search.gov web results API. Creating a new instance of class
  # will and calling #results will return a ResultsResponse upon success or an exception upon failure.
  #
  # @see https://search.usa.gov/sites/7378/api_instructions
  #
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.search'

    configuration Search::Configuration

    attr_reader :query, :page

    def initialize(query, page = 1)
      @query = query
      @page = page.to_i
    end

    # GETs a list of search results from Search.gov web results API
    # @return [Search::ResultsResponse] wrapper around results data
    #
    def results
      with_monitoring do
        response = perform(:get, results_url, query_params)
        Search::ResultsResponse.from(response)
      end
    rescue => e
      handle_error(e)
    end

    private

    def results_url
      config.base_path
    end

    # Required params [affiliate, access_key, query]
    # Optional params [enable_highlighting, limit, offset, sort_by]
    #
    # @see https://search.usa.gov/sites/7378/api_instructions
    #
    def query_params
      {
        affiliate:,
        access_key:,
        query:,
        offset:,
        limit:
      }
    end

    def affiliate
      Settings.search.affiliate
    end

    def access_key
      Settings.search.access_key
    end

    # Calculate the offset parameter based on the requested page number
    #
    def offset
      if page <= 1
        # We want first page of results
        0
      else
        # Max offset for search API is 999
        # If there are 20 results and the user requests page 3, there will be an empty result set
        [((page - 1) * limit), 999].min
      end
    end

    def limit
      Search::Pagination::ENTRIES_PER_PAGE
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        message = parse_messages(error).first
        save_error_details(message)
        handle_429!(error)
        raise_backend_exception('SEARCH_400', self.class, error) if error.status >= 400
      else
        raise error
      end
    end

    def parse_messages(error)
      error.body&.dig('errors')
    end

    def save_error_details(error_message)
      Raven.extra_context(
        message: error_message,
        url: config.base_path
      )
      Raven.tags_context(search: 'general_search_query_error')
    end

    def handle_429!(error)
      return unless error.status == 429

      StatsD.increment("#{Search::Service::STATSD_KEY_PREFIX}.exceptions", tags: ['exception:429'])
      raise_backend_exception('SEARCH_429', self.class, error)
    end
  end
end
