# frozen_string_literal: true

module EVSS
  module AWS
    module ReferenceData
      class Configuration < EVSS::AWS::Configuration
        def base_path
          Settings.evss.aws.url
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
end
