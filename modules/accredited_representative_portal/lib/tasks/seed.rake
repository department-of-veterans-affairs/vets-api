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

# rubocop:disable Metrics/MethodLength, Metrics/ModuleLength, Rails/SkipsModelValidations
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
            factory: %i[
              accredited_individual
              attorney
            ]
          )

          insert_all(
            Records::CLAIMS_AGENTS,
            factory: %i[
              accredited_individual
              claims_agent
            ]
          )

          insert_all(
            Records::ORGANIZATIONS,
            factory: [
              :organization
            ]
          )

          accreditations = []

          insert_all(
            Records::REPRESENTATIVES,
            factory: %i[representative],
            unique_by: %i[first_name last_name representative_id]
          ) do |representative|
            representative[:poa_codes].each do |poa_code|
              accreditations.push(
                accredited_individual_id: representative[:representative_id],
                accredited_organization_id: poa_code
              )
            end
          end

          insert_all(
            Records::CLAIMANTS,
            factory: [
              :user_account
            ]
          )

          insert_poa_requests(
            accreditations
          )

          insert_all(
            Records::USER_ACCOUNT_ACCREDITED_INDIVIDUALS,
            factory: %i[user_account_accredited_individual]
          )
        end
      end

      private

      ##
      # There is one claimant per accreditation. The claimant then gets a permutation
      # of having a series of one of each POA request resolution and applies it.
      # All this cycles around the accreditations. Finally, give each accredited
      # individual one pending POA request.
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
            FactoryBot.build(:power_of_attorney_form)

          RESOLUTION_HISTORY_CYCLE.next.each do |resolution_trait|
            accreditation = accreditation_cycle.next
            created_at = RESOLVED_TIME_TRAVELER.next

            poa_forms.push(claimant_poa_forms[claimant_id].dup)
            resolutions.push(created_at: created_at + 1.day)
            resolution_traits.push(resolution_trait)
            accredited_representative = Veteran::Service::Representative.find_by(
              representative_id: accreditation[:accredited_individual_id]
            )
            poa_requests.push(
              id: Records::POA_REQUEST_IDS.next,
              claimant_type: 'veteran',
              claimant_id:,
              power_of_attorney_holder_type: 'veteran_service_organization',
              poa_code: accreditation[:accredited_organization_id],
              accredited_individual_registration_number: accreditation[:accredited_individual_id],
              accredited_individual: accredited_representative,
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
            # NOTE: need to include an `accredited_individual` so poa code won't be overwritten
            poa_requests.push(
              id: Records::POA_REQUEST_IDS.next,
              claimant_type: 'veteran',
              claimant_id:,
              power_of_attorney_holder_type: 'veteran_service_organization',
              power_of_attorney_holder_poa_code: accreditation[:accredited_organization_id],
              accredited_individual_registration_number: accreditation[:accredited_individual_id],
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

        insert_all(Records::USER_ACCOUNT_ACCREDITED_INDIVIDUALS,
                   factory: %i[user_account_accredited_individual])

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
          status = AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission
                   .statuses.keys.sample
          FactoryBot.create(
            :power_of_attorney_form_submission,
            status:,
            power_of_attorney_request_id: poa_request['id']
          )
        end
      end

      def insert_all(records, factory:, unique_by: nil)
        records =
          records.map.with_index do |record, _i|
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
        %i[expiration declination acceptance]
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
            yielder << (time + 0.days)
            yielder << (time + 10.days)
            yielder << (time + 20.days)
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
# rubocop:enable Metrics/MethodLength, Metrics/ModuleLength, Rails/SkipsModelValidations
