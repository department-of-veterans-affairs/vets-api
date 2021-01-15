# frozen_string_literal: true

require 'uri'
require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'search_click_tracking/response'
require 'search_click_tracking/configuration'

module SearchClickTracking
  # This class builds a wrapper around Search.gov web results API. Creating a new instance of class
  # will and calling #results will return a ResultsResponse upon success or an exception upon failure.
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
    attr_reader :user_agent

    def initialize(url, query, position, client_ip, user_agent)
      @url = url
      @query = query
      @position = position
      @client_ip = client_ip
      @user_agent = user_agent
    end

    # POSTs click tracking query param data to search.gov 
    #
    def track_click
      with_monitoring do
        perform(:post, track_click_url, query_params)
      end
    rescue => e
      handle_error(e)
    end

    private

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
          user_agent: user_agent,
        }
      )
    end

    def affiliate
      Settings.search_click_tracking.affiliate
    end

    def access_key
      Settings.search_click_tracking.access_key
    end

    def module_code
      Settings.search_click_tracking.module_code
    end


    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        message = parse_messages(error).first
        save_error_details(message)
        raise_backend_exception('SEARCH_CLICK_TRACKING_400', self.class, error) if error.status >= 400
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
  end
end
