# frozen_string_literal: true

module EVSS
  module EVSSCommon
    class Configuration < EVSS::Configuration
      API_VERSION = Settings.evss.versions.common

      def base_path
        "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/"
      end

      def service_name
        'EVSS/Common'
      end
    end
  end
end
