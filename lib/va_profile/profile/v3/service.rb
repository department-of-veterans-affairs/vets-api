# frozen_string_literal: true

require_relative 'bio_path_builder'
require_relative 'configuration'
require_relative 'health_benefit_bio_response'
require_relative 'military_occupation_response'
require 'digest'

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
          unless icn_with_aaid
            Rails.logger.error(
              event: 'va_profile.health_benefit_bio.missing_icn_with_aaid',
              user_uuid: user.uuid,
              icn_present: user.icn.present?
            )
            raise Common::Exceptions::BackendServiceException.new('VET360_502', self.class)
          end

          path = "#{oid}/#{ERB::Util.url_encode(icn_with_aaid)}"
          path_hash = Digest::SHA256.hexdigest(path)
          request_body = { bios: [{ bioPath: 'healthBenefit' }] }

          start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
          Rails.logger.info(
            event: 'va_profile.health_benefit_bio.request',
            path_hash:,
            bios_requested: request_body[:bios].size
          )
          service_response = perform(:post, path, request_body)
          latency = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms
          response = VAProfile::Profile::V3::HealthBenefitBioResponse.new(service_response)

          Rails.logger.info(
            event: 'va_profile.health_benefit_bio.response',
            path_hash:,
            upstream_status: response.code,
            contacts_present: response.contacts&.any?,
            latency_ms: latency
          )
          StatsD.measure('va_profile.health_benefit_bio.latency', latency)

          code = response.code || 502
          if response.server_error?
            Rails.logger.error(
              event: 'va_profile.health_benefit_bio.server_error',
              upstream_status: code,
              path_hash:
            )
            raise_backend_exception("VET360_#{code}", self.class)
          end
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
