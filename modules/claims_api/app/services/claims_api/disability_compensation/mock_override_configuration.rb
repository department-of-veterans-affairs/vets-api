# frozen_string_literal: true

require 'evss/disability_compensation_form/configuration'

module ClaimsApi
  module DisabilityCompensation
    class MockOverrideConfiguration < EVSS::DisabilityCompensationForm::Configuration
      def mock_enabled?
        true
      end
    end
  end
end
