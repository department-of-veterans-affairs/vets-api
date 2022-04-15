# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module Demographics
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.demographics.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/demographics/demographics/v1"
      end

      def service_name
        'VAProfile/Demographics'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.demographics.mock || false
      end
    end
  end
end
