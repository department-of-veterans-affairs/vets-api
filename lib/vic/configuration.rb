# frozen_string_literal: true

module VIC
  class Configuration < Common::Client::Configuration::REST
    def base_path
      'https://va--VICDEV.cs33.my.salesforce.com/services/oauth2/token'
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use :breakers
        faraday.request :url_encoded
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
