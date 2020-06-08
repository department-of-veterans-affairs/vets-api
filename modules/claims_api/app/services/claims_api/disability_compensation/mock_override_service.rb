# frozen_string_literal: true

require 'evss/disability_compensation_form/service_all_claim'

module ClaimsApi
  module DisabilityCompensation
    class MockOverrideService < EVSS::DisabilityCompensationForm::ServiceAllClaim
      configuration ClaimsApi::DisabilityCompensation::MockOverrideConfiguration
    end
  end
end
