# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module MilitaryPersonnel
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.military_personnel.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/profile-service/profile/v3"
      end

      def service_name
        'VAProfile/MilitaryPersonnel'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.military_personnel.mock || false
      end
    end
  end
end
