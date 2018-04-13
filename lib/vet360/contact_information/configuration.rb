# frozen_string_literal: true

module Vet360
  module ContactInformation
    class Configuration < Vet360::Configuration
      self.read_timeout = Settings.vet360.contact_information.timeout || 30

      def base_path
        "#{Settings.vet360.url}/person-mdm-cuf-person-hub/cuf/person/contact-information/v1"
      end

      def service_name
        'Vet360'
      end

      def mock_enabled?
        Settings.vet360.contact_information.mock || false
      end
    end
  end
end
