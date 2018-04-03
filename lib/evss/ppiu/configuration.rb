# frozen_string_literal: true

module EVSS
  module PPIU
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.ppiu.timeout || 30

      def base_path
        "#{Settings.evss.url}/wss-ppiu-services-web/rest/ppiuServices/v1"
      end

      def service_name
        'EVSS/PPIU'
      end

      def mock_enabled?
        Settings.evss.mock_ppiu || false
      end
    end
  end
end

