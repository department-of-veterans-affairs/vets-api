# frozen_string_literal: true

module VAProfile
  module HealthBenefit
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring
      configuration VAProfile::ContactInformation::Configuration
    end
  end
end
