# frozen_string_literal: true

module EVSS
  module PPIU
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-ppiu-services-web/rest/ppiuServices/v1"
      end

      def service_name
        'EVSS/PPIU'
      end
    end
  end
end
