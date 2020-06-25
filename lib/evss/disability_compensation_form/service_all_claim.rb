# frozen_string_literal: true

require_relative 'service'
require_relative 'configuration_all_claim'

module EVSS
  module DisabilityCompensationForm
    class ServiceAllClaim < EVSS::DisabilityCompensationForm::Service
      configuration EVSS::DisabilityCompensationForm::ConfigurationAllClaim
    end
  end
end
