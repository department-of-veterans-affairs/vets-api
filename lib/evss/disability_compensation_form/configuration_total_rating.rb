# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Configuration for the all claims version of the 526 form. When all claims is deployed live on production
    # it will live on the same service again as the rest of the end points and `alternate_service_name` can be removed
    #
    class ConfigurationTotalRating < EVSS::DisabilityCompensationForm::Configuration
      # :nocov:
      def base_path
        "#{Settings.evss.url}/wss-common-services-web-11.6/rest/ratingInfoService/11.6"
      end
      # :nocov:

      ##
      # @return [Boolean] Should the service use mock data in lower environments.
      #
      def mock_enabled?
        Settings.evss.mock_total_rating || false
      end
    end
  end
end
