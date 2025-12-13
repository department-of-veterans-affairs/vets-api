# frozen_string_literal: true

module VAProfile
  module PersonSettings
    class Configuration < VAProfile::Configuration
      self.read_timeout = 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/settings-hub/"
      end

      def service_name
        'VAProfile/PersonSettings'
      end

      def mock_enabled?
        false
      end
    end
  end
end
