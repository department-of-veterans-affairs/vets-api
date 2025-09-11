# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_discovery/configuration'

module BenefitsDiscovery
  class Service < Common::Client::Base
    configuration BenefitsDiscovery::Configuration

    def initialize(api_key:, app_id:)
      @api_key = api_key
      @app_id = app_id
      super()
    end

    def get_eligible_benefits(params)
      response = perform(:post, 'benefits-discovery-service/v0/recommendations', params.to_json, headers)
      response.body
    end

    def proxy_request(request)
      method = request.method_symbol
      path = "benefits-discovery-service/#{request.params['path']}"
      body = request.raw_post.presence

      custom_headers = headers.dup
      custom_headers['X-Forwarded-For'] = request.remote_ip

      response = perform(method.downcase.to_sym, path, body, custom_headers)
      response.body
    end

    private

    attr_reader :api_key, :app_id

    def headers
      {
        'x-api-key' => api_key,
        'x-app-id' => app_id
      }
    end
  end
end
