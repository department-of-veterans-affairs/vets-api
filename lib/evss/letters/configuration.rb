# frozen_string_literal: true
module EVSS
  module Letters
    class Configuration < EVSS::Configuration
      DEFAULT_TIMEOUT = Settings.evss.letters.timeout

      def base_path
        "#{Settings.evss.url}/wss-lettergenerator-services-web/rest/letters/v1"
      end

      def service_name
        'EVSS/Letters'
      end

      def mock_enabled?
        Settings.evss.mock_letters || false
      end
    end
  end
end
