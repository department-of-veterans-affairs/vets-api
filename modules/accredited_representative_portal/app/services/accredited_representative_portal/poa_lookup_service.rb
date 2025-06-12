# frozen_string_literal: true

##
# TODO: Remove. This is a temporary workaround for a maintenance period for
# Lighthouse Benefits Claims API in Sandbox.
#
require AccreditedRepresentativePortal::Engine.root.join(
  'lib/accredited_representative_portal/get_power_of_attorney_workaround'
)

module AccreditedRepresentativePortal
  class PoaLookupService
    ##
    # TODO: Remove. This is a temporary workaround for a maintenance period for
    # Lighthouse Benefits Claims API in Sandbox.
    #
    using GetPowerOfAttorneyWorkaround

    attr_reader :claimant_icn

    def initialize(claimant_icn)
      @claimant_icn = claimant_icn
    end

    def claimant_poa_code
      poa_code_response.dig('data', 'attributes', 'code')
    end

    def representative_name
      poa_code_response&.dig('data', 'attributes', 'name')
    end

    def poa_code_response
      @poa_code_response ||= BenefitsClaims::Service.new(claimant_icn).get_power_of_attorney
    end
  end
end
