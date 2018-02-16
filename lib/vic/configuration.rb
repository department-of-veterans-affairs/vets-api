# frozen_string_literal: true

module VIC
  class Configuration < Common::Client::Configuration::REST
    SALESFORCE_INSTANCE_URL = lambda do
      env = Settings.salesforce.env
      suffix = env == 'uat' ? '32' : '33'
      prefix = env.upcase
      prefix = "VIC#{prefix}" unless env == 'uat'

      "https://va--#{prefix}.cs#{suffix}.my.salesforce.com"
    end.call

    def base_path
      "#{SALESFORCE_INSTANCE_URL}/services/oauth2/token"
    end

    def service_name
      'VIC2'
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
