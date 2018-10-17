# frozen_string_literal: true

require 'common/client/base'
require 'search/response'

module Search
  # This class builds a wrapper around Search.gov web results API. Creating a new instance of class
  # will and calling #results will return a ResultsResponse upon success or an exception upon failure.
  #
  # @see https://search.usa.gov/sites/7378/api_instructions
  #
  class Service < Common::Client::Base
    include Common::Client::Monitoring

    STATSD_KEY_PREFIX = 'api.search'

    configuration Search::Configuration

    attr_reader :query
    attr_reader :offset

    def initialize(query, offset = 0)
      @query = query
      @offset = offset.to_i
    end

    # GETs a list of search results from Search.gov web results API
    # @return [Search::ResultsResponse] wrapper around results data
    #
    def results
      with_monitoring do
        response = perform(:get, results_url, query_params)
        Search::ResultsResponse.from(response)
      end
    rescue StandardError => error
      handle_error(error)
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
        affiliate:  affiliate,
        access_key: access_key,
        query:      query,
        offset:     offset,
        limit:      Search::Pagination::OFFSET_LIMIT
      }
    end

    def affiliate
      Settings.search.affiliate
    end

    def access_key
      Settings.search.access_key
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        message = parse_messages(error).first
        log_error_message(message)
        raise_backend_exception('SEARCH_400', self.class, error) if error.status == 400
      else
        raise error
      end
    end

    def parse_messages(error)
      error.body&.dig('errors')
    end

    def log_error_message(error_message)
      log_message_to_sentry(
        error_message,
        :error,
        { url: config.base_path },
        search: 'general_search_query_error'
      )
    end

    def raise_backend_exception(key, source, error = nil)
      raise Common::Exceptions::BackendServiceException.new(
        key,
        { source: source.to_s },
        error&.status,
        error&.body
      )
    end
  end
end
