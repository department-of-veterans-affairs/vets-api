# frozen_string_literal: true

require 'common/client/configuration/rest'

module Mulesoft
  module PreNeed
    class Configuration < Common::Client::Configuration::REST
      def base_path
        "#{Settings.mulesoft.pre_need.url}/api-mbms-mulesoft/selfService/v1/preNeedEligibilityRequest"
      end

      def service_name
        'Mulesoft/PreNeedEligibility'
      end

      def mock_enabled?
        Settings.mulesoft.pre_need.mock || false
      end
    end
  end
end
