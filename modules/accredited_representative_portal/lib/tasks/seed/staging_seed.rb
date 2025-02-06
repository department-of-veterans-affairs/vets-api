module AccreditedRepresentativePortal
  module StagingSeeds
    class << self
      def run
        ActiveRecord::Base.transaction do
          total_created = { requests: 0, resolutions: 0 }

          claimants = create_claimants
          claimant_cycle = claimants.cycle

          resolution_cycle = RESOLUTION_HISTORY_CYCLE.cycle
          resolved_time = RESOLVED_TIME_TRAVELER
          unresolved_time = UNRESOLVED_TIME_TRAVELER

          Veteran::Service::Representative.find_each do |rep|
            matching_orgs = Veteran::Service::Organization.where(poa: rep.poa_codes)
            next if matching_orgs.empty?

            matching_orgs.each do |org|
              create_request_with_resolution(
                org: org,
                rep: rep,
                claimant: claimant_cycle.next,
                resolution_cycle: resolution_cycle,
                resolved_time: resolved_time,
                unresolved_time: unresolved_time,
                totals: total_created
              )
            end
          end

          log_results(total_created)
        end
      end

      private

      RESOLUTION_HISTORY_CYCLE =
        Enumerator.new do |yielder|
          %i[expiration declination acceptance].permutation.each do |perm|
            perm.each do |trait|
              yielder << trait
            end
          end
        end.cycle

      RESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 30.days.ago
          loop do
            yielder << time
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

      def create_claimants(count = 10)
        Array.new(count) do
          FactoryBot.create(:user_account)
        end
      end

      def create_request_with_resolution(org:, rep:, claimant:, resolution_cycle:, resolved_time:, unresolved_time:, totals:)
        if rand < 0.5
          created_at = resolved_time.next
          request = create_poa_request(org, rep, claimant, created_at)
          create_resolution(request, resolution_cycle.next)
          totals[:resolutions] += 1
        else
          request = create_poa_request(org, rep, claimant, unresolved_time.next)
        end
        
        totals[:requests] += 1
      end

      def create_poa_request(org, rep, claimant, created_at)
        PowerOfAttorneyRequest.create!(
          claimant_id: claimant.id,
          claimant_type: 'veteran',
          power_of_attorney_holder_type: 'AccreditedOrganization',
          power_of_attorney_holder_poa_code: org.poa,
          accredited_individual_registration_number: rep.representative_id,
          power_of_attorney_form: build_poa_form,
          created_at: created_at
        )
      end

      def create_resolution(request, resolution_trait)
        FactoryBot.create(
          :power_of_attorney_request_resolution,
          resolution_trait,
          power_of_attorney_request_id: request.id,
          created_at: request.created_at + 1.day
        )
      end

      def build_poa_form
        FactoryBot.build(:power_of_attorney_form)
      end

      def log_results(totals)
        Rails.logger.info(
          "Seeding complete: Created #{totals[:requests]} requests " \
          "and #{totals[:resolutions]} resolutions"
        )
      end
    end
  end
end
