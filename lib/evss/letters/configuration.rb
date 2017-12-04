# frozen_string_literal: true
module EVSS
  module Letters
    class Configuration < EVSS::Configuration
      def request_options
        {
          open_timeout: open_timeout,
          timeout: Settings.evss.letters.timeout
        }
      end

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
