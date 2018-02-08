# frozen_string_literal: true

module VIC
  class Configuration < Common::Client::Configuration::REST
    SALESFORCE_INSTANCE_URL = "https://va--VIC#{Settings.salesforce.env.upcase}.cs33.my.salesforce.com"

    def base_path
      "#{SALESFORCE_INSTANCE_URL}/services/oauth2/token"
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
