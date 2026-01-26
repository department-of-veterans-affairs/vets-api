# frozen_string_literal: true

module Salesforce
  class Configuration < Common::Client::Configuration::REST
    def base_path
      "#{self.class::SALESFORCE_INSTANCE_URL}/services/oauth2/token"
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.request :url_encoded
        faraday.response :json
        faraday.response :betamocks if mock_enabled?
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      false
    end
  end
end
