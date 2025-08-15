# frozen_string_literal: true

module TravelClaim
  class BaseClient
    def initialize
      @settings = Settings.check_in.travel_reimbursement_api_v2
    end

    private

    attr_reader :settings

    def connection(server_url:)
      Faraday.new(url: server_url) do |conn|
        conn.use(:breakers, service_name: settings.service_name)
        conn.response :raise_custom_error, error_prefix: settings.service_name, include_request: true
        conn.response :betamocks if mock_enabled?
        conn.response :json
        conn.request :json
        conn.adapter Faraday.default_adapter
      end
    end

    def claim_headers
      if Settings.vsp_environment == 'production'
        {
          'Ocp-Apim-Subscription-Key-E' => settings.e_subscription_key,
          'Ocp-Apim-Subscription-Key-S' => settings.s_subscription_key
        }
      else
        { 'Ocp-Apim-Subscription-Key' => settings.subscription_key }
      end
    end

    def mock_enabled?
      settings.mock || Flipper.enabled?('check_in_experience_mock_enabled')
    end
  end
end
