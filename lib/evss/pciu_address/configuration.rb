# frozen_string_literal: true
module EVSS
  module PCIUAddress
    class Configuration < EVSS::Configuration
      def request_options
        {
          open_timeout: open_timeout,
          timeout: Settings.evss.pciu_address.timeout
        }
      end

      def base_path
        "#{Settings.evss.url}/wss-pciu-services-web/rest/pciuServices/v1"
      end

      def service_name
        'EVSS/PCIUAddress'
      end

      def mock_enabled?
        Settings.evss.mock_pciu_address || false
      end
    end
  end
end
