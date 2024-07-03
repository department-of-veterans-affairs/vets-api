# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module ProfileInformation
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.profile_information.timeout || 30

      PROFILE_INFORMATION_PATH = 'profile-service/profile/v3'

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/#{PROFILE_INFORMATION_PATH}"
      end

      def service_name
        'VAProfile/ProfileInformation'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.profile_information.use_mocks || false
      end
    end
  end
end