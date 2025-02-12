# frozen_string_literal: true

require_relative 'staging_seed/methods'
require_relative 'staging_seed/constants'

module AccreditedRepresentativePortal
  module StagingSeeds
    class << self
      include Methods
      include Constants

      def run
        ActiveRecord::Base.transaction do
          cleanup_existing_data

          options = build_seeding_options
          orgs = fetch_organizations
          process_organizations(orgs, options)

          Rails.logger.info(
            "Seeding complete: Created #{options[:totals][:requests]} requests, " \
            "#{options[:totals][:resolutions]} resolutions, and " \
            "#{options[:totals][:user_accounts]} user account associations"
          )
        end
      end

      private

      def build_seeding_options
        total_created = { requests: 0, resolutions: 0, user_accounts: 0 }

        {
          claimant_cycle: create_claimants.cycle,
          resolution_cycle: RESOLUTION_HISTORY_CYCLE,
          resolved_time: RESOLVED_TIME_TRAVELER,
          unresolved_time: UNRESOLVED_TIME_TRAVELER,
          totals: total_created,
          email_counter: 0
        }
      end
    end
  end
end
