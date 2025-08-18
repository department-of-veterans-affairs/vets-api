# frozen_string_literal: true

module TravelClaim
  class BaseClient < Common::Client::Base
    def initialize
      @settings = Settings.check_in.travel_reimbursement_api_v2
      super()
    end

    def config
      TravelClaim::Configuration.instance
    end

    def perform(method, path, params, headers = nil, options = nil)
      super(method, path, params, headers, options)
    end

    private

    attr_reader :settings

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
