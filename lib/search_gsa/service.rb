# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'search/response'
require 'search_gsa/configuration'
require 'search/pii_redactor'

module SearchGsa
  # This class builds a wrapper around api.gsa.gov web results API. Creating a new instance of class
  # will and calling #results will return a ResultsResponse upon success or an exception upon failure.
  #
  # @see https://open.gsa.gov/api/searchgov-results/
  #
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.search'

    configuration SearchGsa::Configuration

    attr_reader :query, :page

    def initialize(query, page = 1)
      @query = query
      @page = page.to_i
    end

    # GETs a list of search results from api.gsa,gov API @return
    # [Search::ResultsResponse] wrapper around results data
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
    # @see https://open.gsa.gov/api/searchgov-results/
    #
    def query_params
      {
        affiliate:,
        access_key:,
        query: redacted_query,
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

    def redacted_query
      Search::PiiRedactor.redact(query)
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        # Handle upstream 5xx errors first since the structure of those errors usually isn't the same.
        handle_server_error!(error)
        message = parse_messages(error).first
        save_error_details(message)
        handle_429!(error)
        raise_backend_exception(error_code_name(400), self.class, error) if error.status >= 400
      else
        raise error
      end
    end

    def parse_messages(error)
      error.body&.dig('errors')
    end

    def save_error_details(error_message)
      Sentry.set_extras(
        message: Search::PiiRedactor.redact(error_message),
        url: config.base_path
      )
      Sentry.set_tags(search: 'general_search_query_error')
    end

    def handle_429!(error)
      return unless error.status == 429

      StatsD.increment("#{SearchGsa::Service::STATSD_KEY_PREFIX}.exceptions", tags: ['exception:429'])
      raise_backend_exception(error_code_name(error.status), self.class, error)
    end

    def handle_server_error!(error)
      return unless [503, 504].include?(error.status)

      # Catch when the error's structure doesn't match what's usually expected.
      message = error.body.is_a?(Hash) ? parse_messages(error).first : 'SearchGSA API is down'
      save_error_details(message)
      raise_backend_exception(error_code_name(error.status), self.class, error)
    end

    def error_code_name(error_status)
      "SEARCH_GSA_#{error_status}"
    end
  end
end
