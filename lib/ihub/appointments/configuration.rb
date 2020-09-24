# frozen_string_literal: true

require 'ihub/configuration'

module IHub
  module Appointments
    class Configuration < IHub::Configuration
      self.read_timeout = Settings.ihub.appointments.timeout || 30

      def base_path
        "#{Settings.ihub.url}/WebParts/DEV/api/Appointments/1.0/json/ftpCRM/"
      end

      def service_name
        'iHub/Appointments'
      end

      def mock_enabled?
        Settings.ihub.appointments.mock || false
      end
    end
  end
end
