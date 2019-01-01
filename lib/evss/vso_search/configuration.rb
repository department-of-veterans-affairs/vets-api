# frozen_string_literal: true

module EVSS
  module VsoSearch
    class Configuration < EVSS::Configuration
      API_VERSION = Settings.evss.versions.common

      def base_path
        "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/vsoSearch/11.0/"
      end
  
      def service_name
        'EVSS/VsoSearch'
      end
  
      def mock_enabled?
        Settings.evss.mock_vso_search || false
      end
    end
  end
end  