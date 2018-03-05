# frozen_string_literal: true

module EVSS
  module PCIU
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.pciu.timeout || 30

      def base_path
        "#{Settings.evss.url}/wss-pciu-services-web/rest/pciuServices/v1"
      end

      def service_name
        'EVSS/PCIU'
      end

      def mock_enabled?
        Settings.evss.mock_pciu || false
      end
    end
  end
end
