# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module ContactInformation
    class Configuration < VAProfile::Configuration
      self.read_timeout = Settings.vet360.contact_information.timeout || 30

      def base_path
        "#{Settings.vet360.url}/contact-information-hub/cuf/contact-information/v1"
      end

      def service_name
        'VAProfile/ContactInformation'
      end

      def mock_enabled?
        Settings.vet360.contact_information.mock || false
      end
    end
  end
end
