# frozen_string_literal: true

module CARMA
  module Client
    class Configuration < Salesforce::Configuration
      SALESFORCE_INSTANCE_URL = Settings['salesforce-carma'].url

      def service_name
        'CARMA'
      end

      def mock_enabled?
        Settings['salesforce-carma'].mock
      end
    end
  end
end
