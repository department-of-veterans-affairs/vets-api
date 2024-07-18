# frozen_string_literal: true

require 'brd/brd_response_store'
require 'common/models/concerns/cache_aside'

module ClaimsApi
  ##
  # Class to interact with the BRD API
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  class BRD
    def initialize
      @response_store = BRDResponseStore
    end

    def service_name
      'BENEFITS_REFERENCE_DATA'
    end

    ##
    # List of valid countries
    #
    # @return [Array<String>] list of countries
    def countries
      key = "#{service_name}:countries"
      countries_list = @response_store.get_brd_response(key)
      if countries_list.nil?
        countries_list = client.get('countries').body[:items]
        @response_store.set_brd_response(key, countries_list)
      end
      countries_list
    end

    ##
    # List of intake sites
    #
    # @return [Array<Hash>] list of intake sites
    # as {id: <number> and description: <string>}
    def intake_sites
      key = "#{service_name}:intake-sites"
      sites_list = @response_store.get_brd_response(key)
      if sites_list.nil?
        sites_list = client.get('intake-sites').body[:items]
        @response_store.set_brd_response(key, sites_list)
      end
      sites_list
    end

    def disabilities
      key = "#{service_name}:disabilities"
      disabilities_list = @response_store.get_brd_response(key)
      if disabilities_list.nil?
        disabilities_list = client.get('disabilities').body[:items]
        @response_store.set_brd_response(key, disabilities_list)
      end
      disabilities_list
    end

    def service_branches
      key = "#{service_name}:service-branches"
      branches_list = @response_store.get_brd_response(key)
      if branches_list.nil?
        branches_list = client.get('service-branches').body[:items]
        @response_store.set_brd_response(key, branches_list)
      end
      branches_list
    end

    private

    def client
      base_name = if Settings.brd&.base_name.nil?
                    'api.va.gov/services'
                  else
                    Settings.brd.base_name
                  end

      api_key = Settings.brd&.api_key || ENV.fetch('BRD_API_KEY', '')
      raise StandardError, 'BRD api_key missing' if api_key.blank?

      Faraday.new("https://#{base_name}/benefits-reference-data/v1",
                  # Disable SSL for (localhost) testing
                  ssl: { verify: Settings.brd&.ssl != false },
                  headers: { 'apiKey' => api_key }) do |f|
        f.request :json
        f.response :raise_custom_error
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end
  end
end
