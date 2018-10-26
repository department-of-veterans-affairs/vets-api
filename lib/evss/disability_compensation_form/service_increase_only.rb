# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class ServiceIncreaseOnly < EVSS::DisabilityCompensationForm::Service
      configuration EVSS::DisabilityCompensationForm::ConfigurationIncreaseOnly
    end
  end
end
