# frozen_string_literal: true

require 'evss/disability_compensation_form/configuration_all_claim'

module ClaimsApi
  module DisabilityCompensation
    class MockOverrideConfiguration < EVSS::DisabilityCompensationForm::ConfigurationAllClaim
      def mock_enabled?
        true
      end
    end
  end
end
