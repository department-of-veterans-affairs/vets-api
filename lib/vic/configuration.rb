# frozen_string_literal: true

module VIC
  class Configuration < Common::Client::Configuration::REST
    def self.get_sf_instance_url(env)
      suffix = env == 'uat' ? '32' : '33'
      prefix = env.upcase
      prefix = "VIC#{prefix}" unless env == 'uat'

      "https://va--#{prefix}.cs#{suffix}.my.salesforce.com"
    end

    SALESFORCE_INSTANCE_URL = get_sf_instance_url(Settings.salesforce.env)

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
