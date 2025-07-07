# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_discovery/configuration'
require 'lighthouse/benefits_discovery/params'

module BenefitsDiscovery
  class Service < Common::Client::Base
    configuration BenefitsDiscovery::Configuration

    def get_eligible_benefits(user_uuid)
      response = perform(:post, 'benefits-discovery-service/v0/recommendations', params(user_uuid).to_json, headers)
      response.body['data']
    end

    private

    def params(user_uuid)
      BenefitsDiscovery::Params.new(user_uuid).prepared_params
    end

    def headers
      {
        'x-api-key' => Settings.lighthouse.benefits_discovery.x_api_key,
        'x-app-id' => Settings.lighthouse.benefits_discovery.x_app_id
      }
    end
  end
end
