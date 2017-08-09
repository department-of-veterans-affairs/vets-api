# frozen_string_literal: true
module EVSS
  module Letters
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-lettergenerator-services-web/rest/letters/v1"
      end

      def service_name
        'EVSS::Letters'
      end
    end
  end
end
