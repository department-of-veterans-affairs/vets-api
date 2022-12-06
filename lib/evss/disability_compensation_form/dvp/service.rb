# frozen_string_literal: true

require_relative 'configuration'

module EVSS
  module DisabilityCompensationForm
    module Dvp
      # An extension of EVSS::DisabilityCompensationForm::Service that uses a
      # Configuration that points to the EVSS Form 526 instance that's hosted
      # on the Digital Veterans Platform
      class Service < EVSS::DisabilityCompensationForm::Service
        configuration EVSS::DisabilityCompensationForm::Dvp::Configuration
      end
    end
  end
end
