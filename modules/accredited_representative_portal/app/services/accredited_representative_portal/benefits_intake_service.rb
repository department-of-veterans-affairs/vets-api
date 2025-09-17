# frozen_string_literal: true

module AccreditedRepresentativePortal
  class BenefitsIntakeService < BenefitsIntakeService::Service
    configuration BenefitsIntakeConfiguration # ARP-specific configuration

    def initialize(*)
      super(*)
      @uuid = get_location_and_uuid[:uuid]
      @location = get_location_and_uuid[:location]
    end
  end
end
