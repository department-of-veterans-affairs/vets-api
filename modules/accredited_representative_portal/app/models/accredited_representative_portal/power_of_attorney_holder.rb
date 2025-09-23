# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyHolder <
    Data.define(
      :type, :poa_code, :name,
      :can_accept_digital_poa_requests
    )
    module Types
      ALL = [
        VETERAN_SERVICE_ORGANIZATION = 'veteran_service_organization',
        CLAIMS_AGENT = 'claims_agent',
        ATTORNEY = 'attorney'
      ].freeze
    end

    PRIMARY_KEY_ATTRIBUTE_NAMES = %i[
      type
      poa_code
    ].freeze

    def accepts_digital_power_of_attorney_requests?
      can_accept_digital_poa_requests
    end
  end
end
