# frozen_string_literal: true

require 'common/client/configuration/rest'

module TravelClaim
  class Configuration < Common::Client::Configuration::REST
    include Singleton

    attr_writer :server_url

    def base_path
      Settings.check_in.travel_reimbursement_api_v2.claims_url_v2
    end

    def service_name
      'TravelClaim'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :json
        conn.response :json
        conn.response :raise_custom_error, error_prefix: service_name, include_request: true
        conn.response :betamocks if mock_enabled?

        conn.adapter Faraday.default_adapter
      end
    end

    private

    def mock_enabled?
      Settings.check_in.travel_reimbursement_api_v2.mock || Flipper.enabled?('check_in_experience_mock_enabled')
    end
  end
end
