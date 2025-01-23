# frozen_string_literal: true

require_relative 'bio_path_builder'
require_relative 'configuration'
require_relative 'health_benefit_bio_response'
require_relative 'military_occupation_response'

module VAProfile
  module Profile
    module V3
      # NOTE: This controller is used for discovery purposes.
      # Please contact the Authenticated Experience Profile team before using.
      class Service < Common::Client::Base
        configuration VAProfile::Profile::V3::Configuration

        OID = '2.16.840.1.113883.3.42.10001.100001.12'
        AAID = '^NI^200DOD^USDOD'

        attr_reader :user

        def initialize(user)
          @user = user
          super()
        end

        def get_health_benefit_bio
          oid = MPI::Constants::VA_ROOT_OID
          path = "#{oid}/#{ERB::Util.url_encode(icn_with_aaid)}"
          service_response = perform(:post, path, { bios: [{ bioPath: 'healthBenefit' }] })
          response = VAProfile::Profile::V3::HealthBenefitBioResponse.new(service_response)
          Sentry.set_extras(response.debug_data) unless response.ok?
          code = response.code || 502
          raise_backend_exception("VET360_#{code}", self.class) if response.server_error?
          response
        end

        def get_military_info
          config.submit(path(@user.edipi), body)
        end

        def get_military_occupations
          builder = VAProfile::Profile::V3::BioPathBuilder.new(:military_occupations)
          response = submit(builder.params)
          VAProfile::Profile::V3::MilitaryOccupationResponse.new(response)
        end

        def submit(params)
          config.submit(path(@user.edipi), params)
        end

        private

        def icn_with_aaid
          return "#{user.idme_uuid}^PN^200VIDM^USDVA" if user.idme_uuid
          return "#{user.logingov_uuid}^PN^200VLGN^USDVA" if user.logingov_uuid

          nil
        end

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
