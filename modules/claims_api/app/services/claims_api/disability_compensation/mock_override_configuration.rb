# frozen_string_literal: true

module ClaimsApi
  module DisabilityCompensation
    class MockOverrideConfiguration < EVSS::DisabilityCompensationForm::Configuration
      def mock_enabled?
        true
      end
    end
  end
end
