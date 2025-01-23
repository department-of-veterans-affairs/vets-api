# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module V2
    module ContactInformation
      class Configuration < VAProfile::Configuration
        self.read_timeout = VAProfile::Configuration::SETTINGS.contact_information.timeout || 30

        def base_path
          "#{VAProfile::Configuration::SETTINGS.url}/contact-information-hub/contact-information/v2"
        end

        def service_name
          'VAProfile/V2/ContactInformation'
        end

        def mock_enabled?
          VAProfile::Configuration::SETTINGS.contact_information.mock || false
        end
      end
    end
  end
end
