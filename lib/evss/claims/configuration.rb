# frozen_string_literal: true
module EVSS
  module Claims
    class Configuration < EVSS::Configuration
      API_VERSION = Settings.evss.versions.claims

      def base_path
        "#{Settings.evss.url}/wss-claims-services-web-#{API_VERSION}/rest"
      end

      def service_name
        'EVSS/Claims'
      end
    end
  end
end
