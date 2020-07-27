# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Configuration for the all claims version of the 526 form. When all claims is deployed live on production
    # it will live on the same service again as the rest of the end points and `alternate_service_name` can be removed
    #
    class ConfigurationAllClaim < EVSS::DisabilityCompensationForm::Configuration
      # :nocov:
      def base_path
        "#{Settings.evss.url}/#{Settings.evss.alternate_service_name}/rest/form526/v2"
      end
      # :nocov:
    end
  end
end
