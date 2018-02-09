# frozen_string_literal: true

module EVSS
  module ReferenceData
    class Configuration < EVSS::AWSConfiguration
      def base_path
        Settings.evss.aws.url.to_s
      end

      def service_name
        'EVSS/AWS/ReferenceData'
      end

      def mock_enabled?
        # TODO: create mock data
        false
      end
    end
  end
end
