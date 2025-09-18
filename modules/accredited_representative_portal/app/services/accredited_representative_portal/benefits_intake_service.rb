# frozen_string_literal: true

module AccreditedRepresentativePortal
  class BenefitsIntakeService < BenefitsIntakeService::Service
    configuration BenefitsIntakeConfiguration # ARP-specific configuration

    def initialize(*)
      super(*)
    end
  end
end
