# frozen_string_literal: true

require_relative 'seed/records'

namespace :accredited_representative_portal do
  desc <<~MSG.squish
    Seeds accredited representative and POA request records
  MSG
  task seed: :environment do
    unless Rails.env.development?
      Rails.logger.warn(<<~MSG.squish)
        Whoops! This task can only be run in the development environment.
        Stopping now.
      MSG

      exit!(1)
    end

    AccreditedRepresentativePortal::Seed.run
  end
end

module AccreditedRepresentativePortal
  ##
  # Representative records derived from here:
  # https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/44b9fdb497587a46837b65f55827e16e1fde6547/products/accredited-representation-management/accredited-entities-test-data.md
  #
  module Seed
    class << self
      def run
        ActiveRecord::Base.transaction do
          insert_all(
            Records::ATTORNEYS,
            factory: [
              :accredited_individual,
              :attorney
            ]
          )

          insert_all(
            Records::CLAIMS_AGENTS,
            factory: [
              :accredited_individual,
              :claims_agent
            ]
          )

          insert_all(
            Records::ORGANIZATIONS,
            factory: [
              :accredited_organization
            ]
          )

          accreditations = []

          insert_all(
            Records::REPRESENTATIVES,
            factory: [
              :accredited_individual,
              :representative
            ]
          ) do |representative|
            representative
              .delete(:organization_ids)
              .each do |organization_id|
                accreditations.push(
                  accredited_individual_id: representative[:id],
                  accredited_organization_id: organization_id
                )
              end
          end

          insert_all(
            accreditations,
            factory: [
              :accreditation
            ],
            unique_by: [
              :accredited_organization_id,
              :accredited_individual_id
            ]
          )

          insert_all(
            Records::CLAIMANTS,
            factory: [
              :user_account
            ]
          )

          insert_poa_requests(
            accreditations
          )
        end
      end

      private

      ##
      # There is one claimant per accreditation. The claimant then gets a permutation
      # of having a series of one of each POA request resolution and applies it.
      # All this cycles around the accreditations. Finally, give each accredited
      # individual one unresolved POA request.
      #
      def insert_poa_requests(accreditations)
        poa_forms = []
        resolutions = []
        resolution_traits = []
        poa_requests = []

        accreditation_cycle = accreditations.cycle
        claimant_poa_forms = {}

        Records::CLAIMANTS.each do |claimant|
          claimant_id = claimant[:id]
          claimant_poa_forms[claimant_id] =
            FactoryBot.build(:dynamic_power_of_attorney_form)

          RESOLUTION_HISTORY_CYCLE.next.each do |resolution_trait|
            accreditation = accreditation_cycle.next
            created_at = RESOLVED_TIME_TRAVELER.next

            poa_forms.push(claimant_poa_forms[claimant_id].dup)
            resolutions.push(created_at: created_at + 1.day)
            resolution_traits.push(resolution_trait)
            poa_requests.push(
              id: Records::POA_REQUEST_IDS.next,
              claimant_type: 'veteran',
              claimant_id:,
              power_of_attorney_holder_type: 'AccreditedOrganization',
              power_of_attorney_holder_id: accreditation[:accredited_organization_id],
              accredited_individual_id: accreditation[:accredited_individual_id],
              created_at:
            )
          end
        end

        accreditations
          .uniq { |a| a[:accredited_individual_id] }
          .each_with_index do |accreditation, i|
            claimant_id = Records::CLAIMANTS[i][:id]
            created_at = UNRESOLVED_TIME_TRAVELER.next

            poa_forms.push(claimant_poa_forms[claimant_id].dup)
            poa_requests.push(
              id: Records::POA_REQUEST_IDS.next,
              claimant_type: 'veteran',
              claimant_id:,
              power_of_attorney_holder_type: 'AccreditedOrganization',
              power_of_attorney_holder_id: accreditation[:accredited_organization_id],
              accredited_individual_id: accreditation[:accredited_individual_id],
              created_at:
            )
          end

        inserted_poa_requests =
          insert_all(
            poa_requests,
            factory: [
              :power_of_attorney_request
            ]
          )

        ##
        # Forms and resolutions can't happen in bulk because encryption happens
        # per record unfortunately.
        #
        inserted_poa_requests.each_with_index do |poa_request, i|
          # All need their form.
          poa_forms[i].update!(
            power_of_attorney_request_id: poa_request['id']
          )

          # But not all are resolved.
          next unless resolutions[i]

          FactoryBot.create(
            :power_of_attorney_request_resolution,
            resolution_traits[i],
            power_of_attorney_request_id: poa_request['id'],
            **resolutions[i]
          )
        end
      end

      def insert_all(records, factory:, unique_by: nil)
        records =
          records.map.with_index do |record, i|
            yield(record) if block_given?

            FactoryBot
              .build(*factory, **record)
              .attributes
              # This would defeat explicit nils.
              .tap(&:compact!)
          end

        FactoryBot::Internal
          .factory_by_name(factory[0])
          .build_class
          .insert_all(
            records,
            unique_by:
          )
      end

      RESOLUTION_HISTORY_CYCLE =
        [:expiration, :declination, :acceptance]
          .permutation
          .cycle

      RESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 30.days.ago

          loop do
            ##
            # These 3 entries spread are here because we are making 3 POA
            # requests per claimant in a row.
            #
            yielder << time + 0.days
            yielder << time + 10.days
            yielder << time + 20.days
            time += 6.hours
          end
        end

      UNRESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 10.days.ago

          loop do
            yielder << time
            time += 6.hours
          end
        end
    end
  end
end
