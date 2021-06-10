# frozen_string_literal: true

require 'uri'
require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'search_click_tracking/configuration'

module SearchClickTracking
  # This class builds a wrapper around Search.gov web click tracking API.
  #
  # @see https://search.usa.gov/sites/7378/api_instructions
  #
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.search_click_tracking'

    configuration SearchClickTracking::Configuration

    attr_reader :url
    attr_reader :query
    attr_reader :position
    attr_reader :client_ip
    attr_reader :module_code
    attr_reader :user_agent

    # rubocop:disable Metrics/ParameterLists
    def initialize(url, query, position, user_agent, module_code = 'I14Y', client_ip = request.remote_ip)
      @url = url
      @query = query
      @position = position
      @client_ip = client_ip
      @user_agent = user_agent
      @module_code = module_code
    end
    # rubocop:enable Metrics/ParameterLists

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

    # Required params [affiliate, access_key, module_code, url, query, position, client_ip, user_agent]
    #
    # @see https://search.usa.gov/sites/7378/api_instructions
    #
    def query_params
      URI.encode_www_form(
        {
          affiliate: affiliate,
          access_key: access_key,
          module_code: module_code,
          url: url,
          query: query,
          position: position,
          client_ip: client_ip,
          user_agent: user_agent
        }
      )
    end

    def affiliate
      Settings.search_click_tracking.affiliate
    end

    def access_key
      Settings.search_click_tracking.access_key
    end
  end
end
