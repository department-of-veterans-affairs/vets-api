# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Configuration for the findRatingInfoPID service
    #
    class ConfigurationRatingInfo < EVSS::DisabilityCompensationForm::Configuration
      # :nocov:
      def base_path
        "#{Settings.evss.url}/wss-common-services-web-11.6/rest/ratingInfoService/11.6"
      end
      # :nocov:

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_rating_info || false
      end
    end
  end
end
