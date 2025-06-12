# frozen_string_literal: true

module AccreditedRepresentativePortal
  ##
  # TODO: Remove. This is a temporary workaround for a maintenance period for
  # Lighthouse Benefits Claims API in Sandbox.
  #
  module GetPowerOfAttorneyWorkaround
    ##
    # THIS DEMOGRAPHIC INFO AND ICN ARE PURELY FICTIONAL STAGING DATA
    #
    # ```
    # MPI::Service.new.find_profile_by_attributes(
    #   ssn: '796229088',
    #   first_name: 'Derrick',
    #   last_name: 'Reid',
    #   birth_date: '1976-01-16'
    # ).profile.icn
    # ```
    #
    ICN_WITH_POA = '1012845660V369114'

    ##
    # THIS DEMOGRAPHIC INFO AND ICN ARE PURELY FICTIONAL STAGING DATA
    #
    # ```
    # MPI::Service.new.find_profile_by_attributes(
    #   ssn: '796068291',
    #   first_name: 'Derrick',
    #   last_name: 'Stewart',
    #   birth_date: '1967-10-30'
    # ).profile.icn
    # ```
    #
    ICN_WITHOUT_POA = '1012592999V810903'

    refine BenefitsClaims::Service do
      def get_power_of_attorney(...) # rubocop:disable Metrics/MethodLength
        Settings.vsp_environment == 'staging' or
          return super

        Flipper.enabled?(:accredited_representative_portal_get_power_of_attorney_workaround) or
          return super

        case @icn
        when ICN_WITH_POA
          {
            'data' => {
              'type' => 'organization',
              'attributes' => {
                'code' => '008',
                'name' => 'Tamara Ellis',
                'phoneNumber' => '555-555-5555'
              }
            }
          }
        when ICN_WITHOUT_POA
          { 'data' => {} }
        else
          super
        end
      end
    end
  end
end
