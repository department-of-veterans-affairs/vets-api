# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module ProfileInformation
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.profile_information.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/contact-information-hub/cuf/contact-information/v2"
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
