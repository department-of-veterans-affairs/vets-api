# frozen_string_literal: true

require 'benefits_intake_service/service'

module AccreditedRepresentativePortal
  class BenefitsIntakeService < ::BenefitsIntakeService::Service
    configuration BenefitsIntakeConfiguration # ARP-specific configuration
  end
end
