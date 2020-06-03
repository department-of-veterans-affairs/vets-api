# frozen_string_literal: true

require_relative 'service'
require_relative 'configuration_increase_only'

module EVSS
  module DisabilityCompensationForm
    class ServiceIncreaseOnly < EVSS::DisabilityCompensationForm::Service
      configuration EVSS::DisabilityCompensationForm::ConfigurationIncreaseOnly
    end
  end
end
