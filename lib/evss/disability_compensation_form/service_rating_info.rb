# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class ServiceRatingInfo < EVSS::DisabilityCompensationForm::Service
      configuration EVSS::DisabilityCompensationForm::ConfigurationRatingInfo
    end
  end
end
