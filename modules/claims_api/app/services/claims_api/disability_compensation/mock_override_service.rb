# frozen_string_literal: true

module ClaimsApi
  module DisabilityCompensation
    class MockOverrideService < EVSS::DisabilityCompensationForm::ServiceAllClaim
      configuration ClaimsApi::DisabilityCompensation::MockOverrideConfiguration
    end
  end
end
