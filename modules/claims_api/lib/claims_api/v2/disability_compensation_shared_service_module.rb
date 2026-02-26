# frozen_string_literal: true

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationSharedServiceModule
      VALID_RESERVES_BRANCH_NAMES = %w[
        RESERVES
        AIR_NATIONAL_GUARD
        ARMY_NATIONAL_GUARD
      ].freeze

      def eligible_for_future_end_date?(max_period, service_periods)
        most_recent_service_branch_is_reserves_or_guard?(max_period) && past_service_period?(service_periods)
      end

      def most_recent_service_branch_is_reserves_or_guard?(max_period)
        most_recent_service_branch_name = max_period['serviceBranch']&.upcase
        return false if most_recent_service_branch_name.blank?

        VALID_RESERVES_BRANCH_NAMES.any? { |name| most_recent_service_branch_name.include?(name) }
      end

      def past_service_period?(service_periods)
        return false if service_periods.blank?

        service_periods.any? do |sp|
          end_date = sp['activeDutyEndDate']
          next false if end_date.blank?

          Date.parse(end_date) <= Time.zone.today.end_of_day
        end
      end

      def brd
        @brd ||= BRD.new
      end

      def retrieve_separation_locations
        @intake_sites ||= brd.intake_sites
      end

      def brd_service_branch_names
        @brd_service_branch_names ||= brd_service_branches&.pluck(:description)
      end

      def brd_service_branches
        @brd_service_branches ||= brd.service_branches
      end

      def valid_countries
        @valid_countries ||= brd.countries
      end

      def brd_classification_ids
        @brd_classification_ids ||= brd_disabilities&.pluck(:id)
      end

      def brd_disabilities
        @brd_disabilities ||= brd.disabilities
      end
    end
  end
end
