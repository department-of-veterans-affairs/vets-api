require_relative 'staging_seed/methods'
require_relative 'staging_seed/constants'

module AccreditedRepresentativePortal
  module StagingSeeds
    class << self
      include Methods
      include Constants

      def run
        ActiveRecord::Base.transaction do
          total_created = { requests: 0, resolutions: 0 }

          claimants = create_claimants
          claimant_cycle = claimants.cycle

          resolution_cycle = RESOLUTION_HISTORY_CYCLE
          resolved_time = RESOLVED_TIME_TRAVELER
          unresolved_time = UNRESOLVED_TIME_TRAVELER

          # CT Digital Organization
          ct_org = Veteran::Service::Organization.find_by(poa: "008")
          
          # Other Digital Organizations (limit 2)
          other_digital_orgs = Veteran::Service::Organization
            .where(can_accept_digital_poa_requests: true)
            .where.not(poa: "008")
            .limit(2)
          
          # Non-Digital Organizations (limit 2)
          non_digital_orgs = Veteran::Service::Organization
            .where(can_accept_digital_poa_requests: false)
            .limit(2)

          # Create requests for each org type
          [ct_org, *other_digital_orgs, *non_digital_orgs].each do |org|
            matching_reps = Veteran::Service::Representative
              .where("poa_codes && ARRAY[?]::varchar[]", [org.poa])
              .limit(2)

            matching_reps.each do |rep|
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

          Rails.logger.info(
            "Seeding complete: Created #{total_created[:requests]} requests " \
            "and #{total_created[:resolutions]} resolutions"
          )
        end
      end
    end
  end
end
