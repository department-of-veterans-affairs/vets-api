# frozen_string_literal: true

module BenefitsDiscovery
  class Configuration < Common::Client::Configuration::REST

    # all lower environments are currently configured to point to sandbox
    # for newest changes to service, switch AWS params to point to dev
    def base_path
      Settings.lighthouse.benefits_discovery.host
    end

    def service_name
      'BenefitsDiscovery'
    end

    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
