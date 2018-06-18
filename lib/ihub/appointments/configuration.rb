# frozen_string_literal: true

module IHub
  module Appointments
    class Configuration < IHub::Configuration
      def base_path
        'https://qacrmdac.np.crm.vrm.vba.va.gov/WebParts/DEV/api/Appointments/1.0/json/ftpCRM'
      end

      def service_name
        'iHub/Appointments'
      end
    end
  end
end
