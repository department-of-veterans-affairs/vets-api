# frozen_string_literal: true

module Vet360
  module ReferenceData
    class Configuration < Vet360::Configuration
      self.read_timeout = 30

      def base_path
        "#{Settings.vet360.url}/contact-information-hub/referencedata/contact-information/v1"
      end

      def service_name
        'Vet360/ReferenceData'
      end
    end
  end
end
