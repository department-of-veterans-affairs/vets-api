# frozen_string_literal: true

module EVSS
  module Letters
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.letters.timeout || 55

      def base_path
        "#{Settings.evss.letters.url}/wss-lettergenerator-services-web/rest/letters/v1"
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
