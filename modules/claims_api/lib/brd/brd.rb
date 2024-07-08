# frozen_string_literal: true

require 'library_base'

module ClaimsApi
  ##
  # Class to interact with the BRD API
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  class BRD < LibraryBase
    ##
    # List of valid countries
    #
    # @return [Array<String>] list of countries
    def countries
      handle_transaction('countries')
    end

    ##
    # List of intake sites
    #
    # @return [Array<Hash>] list of intake sites
    # as {id: <number> and description: <string>}
    def intake_sites
      handle_transaction('intake-sites')
    end

    def disabilities
      handle_transaction('disabilities')
    end

    def service_branches
      handle_transaction('service-branches')
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
