# frozen_string_literal: true

require 'uri'
require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'search_click_tracking/configuration'
require 'search/pii_redactor'

module SearchClickTracking
  # This class builds a wrapper around Search.gov web click tracking API.
  #
  # @see https://search.usa.gov/sites/7378/api_instructions
  #
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.search_click_tracking'

    configuration SearchClickTracking::Configuration

    attr_reader :url, :query, :position, :module_code, :user_agent

    def initialize(url, query, position, user_agent, module_code = 'I14Y')
      @url = url
      @query = query
      @position = position
      @user_agent = user_agent
      @module_code = module_code
    end

    # POSTs click tracking query param data to search.gov
    #
    def track_click
      with_monitoring do
        Faraday.post(url_with_params, '')
      end
    rescue => e
      e
    end

    private

    def url_with_params
      "#{track_click_url}?#{query_params}"
    end

    def track_click_url
      config.base_path
    end

    # Required params [affiliate, access_key, module_code, url, query, position, user_agent]
    #
    # @see https://search.usa.gov/sites/7378/api_instructions
    #
    def query_params
      URI.encode_www_form(
        {
          affiliate:,
          access_key:,
          module_code:,
          url: redacted_url,
          query: redacted_query,
          position:,
          user_agent: redacted_user_agent
        }
      )
    end

    def affiliate
      Settings.search_click_tracking.affiliate
    end

    def access_key
      Settings.search_click_tracking.access_key
    end

    def redacted_url
      Search::PiiRedactor.redact(url)
    end

    def redacted_query
      Search::PiiRedactor.redact(query)
    end

    def redacted_user_agent
      Search::PiiRedactor.redact(user_agent)
    end
  end
end
