# frozen_string_literal: true
module EVSS
  module PCIUAddress
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-pciu-services-web/rest/pciuServices/v1"
      end

      def service_name
        'EVSS::PCIUAdress'
      end
    end
  end
end
