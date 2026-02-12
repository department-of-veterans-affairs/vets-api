# frozen_string_literal: true

require 'mhv/oh_facilities_helper/service'

module MHV
  module Prescriptions
    # Filters prescription refill orders based on Oracle Health migration status.
    # Facilities in blocking phases (p4-p6, i.e. T-3 to T+2) are returned as failures
    # without being sent to the upstream service.
    #
    # Usage:
    #   filter = MHV::Prescriptions::OhTransitionRefillFilter.new(current_user)
    #   allowed_orders, blocked_failures = filter.partition_orders(parsed_orders)
    #
    # Gated by the :mhv_medications_oh_transition_refill_block Flipper flag.
    class OhTransitionRefillFilter
      BLOCKED_PHASES = %w[p4 p5 p6].freeze
      BLOCKED_ERROR_MESSAGE = 'Refill blocked: facility is transitioning to Oracle Health'

      def initialize(user)
        @user = user
      end

      # Partitions orders into allowed and OH-blocked groups.
      # @param orders [Array<Hash>] parsed order hashes with 'stationNumber' and 'id' keys
      # @return [Array(Array<Hash>, Array<Hash>)] [allowed_orders, blocked_failures]
      #   blocked_failures use the standard { id:, error:, station_number: } format
      def partition_orders(orders)
        return [orders, []] unless Flipper.enabled?(:mhv_medications_oh_transition_refill_block, @user)

        station_numbers = orders.map { |o| o['stationNumber'] }.compact.uniq
        phases_map = oh_facilities_helper.get_phases_for_station_numbers(station_numbers)
        blocked_phases = BLOCKED_PHASES

        allowed = []
        blocked_failures = []

        orders.each do |order|
          phase = phases_map[order['stationNumber'].to_s]
          if blocked_phases.include?(phase)
            blocked_failures << {
              id: order['id'],
              error: BLOCKED_ERROR_MESSAGE,
              station_number: order['stationNumber']
            }
          else
            allowed << order
          end
        end

        [allowed, blocked_failures]
      end

      # Merges upstream API results with locally-blocked OH failures.
      # @param api_result [Hash] { success: [...], failed: [...] } from upstream service
      # @param blocked_failures [Array<Hash>] failures from partition_orders
      # @return [Hash] merged { success: [...], failed: [...] }
      def self.merge_results(api_result, blocked_failures)
        return api_result if blocked_failures.blank?

        {
          success: api_result[:success] || [],
          failed: (api_result[:failed] || []) + blocked_failures
        }
      end

      private

      def oh_facilities_helper
        @oh_facilities_helper ||= MHV::OhFacilitiesHelper::Service.new(@user)
      end
    end
  end
end
