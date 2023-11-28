# frozen_string_literal: true

require_relative 'configuration'

module VAProfile
  module Profile
    module V3
      # NOTE: This controller is used for discovery purposes.
      # Please contact the Authenticated Experience Profile team before using.
      class Service < Common::Client::Base
        configuration VAProfile::Profile::V3::Configuration

        OID = '2.16.840.1.113883.3.42.10001.100001.12'
        AAID = '^NI^200DOD^USDOD'

        def initialize(user)
          @user = user
          super()
        end

        def get_military_info
          config.post(path(@user.edipi), body)
        end

        private

        def body
          {
            bios: [
              { bioPath: 'militaryPerson.adminDecisions' },
              { bioPath: 'militaryPerson.adminEpisodes' },
              { bioPath: 'militaryPerson.dentalIndicators' },
              { bioPath: 'militaryPerson.militaryOccupations', parameters: { scope: 'all' } },
              { bioPath: 'militaryPerson.militaryServiceHistory', parameters: { scope: 'all' } },
              { bioPath: 'militaryPerson.militarySummary' },
              { bioPath: 'militaryPerson.militarySummary.customerType.dodServiceSummary' },
              { bioPath: 'militaryPerson.payGradeRanks', parameters: { scope: 'highest' } },
              { bioPath: 'militaryPerson.prisonerOfWars' },
              { bioPath: 'militaryPerson.transferOfEligibility' },
              { bioPath: 'militaryPerson.retirements' },
              { bioPath: 'militaryPerson.separationPays' },
              { bioPath: 'militaryPerson.retirementPays' },
              { bioPath: 'militaryPerson.combatPays' },
              { bioPath: 'militaryPerson.unitAssignments' }
            ]
          }
        end

        def path(edipi)
          "#{OID}/#{ERB::Util.url_encode("#{edipi}#{AAID}")}"
        end
      end
    end
  end
end
