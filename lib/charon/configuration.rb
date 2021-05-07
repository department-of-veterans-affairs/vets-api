# frozen_string_literal: true

require 'common/client/configuration/rest'

module CHARON
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.oidc.charon.endpoint || ''
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use :breakers
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    def service_name
      'CHARON'
    end
  end
end
