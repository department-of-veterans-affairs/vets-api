# frozen_string_literal: true
module EVSS
  module ReferenceData
    class Configuration < EVSS::Configuration
      def base_path
        # TODO: integrate with Settings.yml & devops
        'https://internal-staging-services-1341723990.us-gov-west-1.elb.amazonaws.com/api/refdata/v1'
      end

      def service_name
        'EVSS/ReferenceData'
      end

      def mock_enabled?
        # TODO: create mock data
        false
      end
    end
  end
end
