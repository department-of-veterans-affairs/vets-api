# frozen_string_literal: true

require 'common/client/configuration/rest'

module Okta
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.oidc.base_api_url || ''
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use :breakers
        faraday.response :json
        faraday.response :betamocks if Settings.oidc.mock
        faraday.adapter Faraday.default_adapter
      end
    end

    def service_name
      'OKTA'
    end
  end
end
