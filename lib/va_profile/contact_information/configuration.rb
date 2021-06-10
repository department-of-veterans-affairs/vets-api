# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module ContactInformation
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.contact_information.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/contact-information-hub/cuf/contact-information/v1"
      end

      def service_name
        'VAProfile/ContactInformation'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.contact_information.mock || false
      end
    end
  end
end
