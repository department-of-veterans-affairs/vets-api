# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Configuration for the findRatingInfoPID service
    #
    class ConfigurationRatingInfo < EVSS::DisabilityCompensationForm::Configuration
      API_VERSION = Settings.evss.versions.common

      def base_path
        "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/ratingInfoService/#{API_VERSION}"
      end

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_rating_info || false
      end
    end
  end
end
