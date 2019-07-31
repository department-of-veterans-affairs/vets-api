# frozen_string_literal: true

module ClaimsApi
  module DisabilityCompensation
    class MockOverrideConfiguration < EVSS::DisabilityCompensationForm::ConfigurationAllClaim
      def mock_enabled?
        true
      end
    end
  end
end
