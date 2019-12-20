# frozen_string_literal: true

module BipClaims
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.bip.claims.url
    end

    def service_name
      'BipClaims'
    end

    def connection
      Faraday.new(base_path) do |faraday|
        faraday.use     :breakers

        faraday.request :multipart
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
