# frozen_string_literal: true

module VAProfile
  module Communication
    class Configuration < VAProfile::Configuration
      def base_path
        "#{Settings.vet360.url}/communication-hub/communication/v1/"
      end

      def service_name
        'VAProfile/Communication'
      end
    end
  end
end
