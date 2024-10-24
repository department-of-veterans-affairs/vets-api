# frozen_string_literal: true

require 'brd/brd_response_store'
require 'library_base'

module ClaimsApi
  ##
  # Class to interact with the BRD API
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  class BRD < LibraryBase
    def initialize
      @response_store = BRDResponseStore
      super()
    end

    def service_name
      'BENEFITS_REFERENCE_DATA'
    end

    ##
    # List of valid countries
    #
    # @return [Array<String>] list of countries
    def countries
      response_from_cache_or_service('countries')
    rescue => e
      rescue_brd(e, 'countries')
    end

    ##
    # List of intake sites
    #
    # @return [Array<Hash>] list of intake sites
    # as {id: <number> and description: <string>}
    def intake_sites
      response_from_cache_or_service('intake-sites')
    rescue => e
      rescue_brd(e, 'intake-sites')
    end

    def disabilities
      response_from_cache_or_service('disabilities')
    rescue => e
      rescue_brd(e, 'disabilities')
    end

    def service_branches
      response_from_cache_or_service('service-branches')
    rescue => e
      rescue_brd(e, 'service-branches')
    end

    private

    def response_from_cache_or_service(brd_service)
      key = "#{service_name}:#{brd_service}"
      response = @response_store.get_brd_response(key)
      if response.nil?
        response = client.get(brd_service).body[:items]
        @response_store.set_brd_response(key, response)
      end
      response
    end

    def client
      base_name = if Settings.brd&.base_name.nil?
                    'api.va.gov/services'
                  else
                    Settings.brd.base_name
                  end

      api_key = Settings.brd&.api_key || ''
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

    def rescue_brd(e, service)
      detail = e.respond_to?(:original_body) ? e.original_body : e
      log_outcome_for_claims_api(service, 'error', detail)

      error_handler(e)
    end
  end
end
