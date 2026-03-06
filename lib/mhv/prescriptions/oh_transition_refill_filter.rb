# frozen_string_literal: true

require 'mhv/oh_facilities_helper/service'

module MHV
  module Prescriptions
    # Filters prescription refill orders based on Oracle Health migration status.
    # Facilities in blocking phases (p4-p6, i.e. T-3 to T+2) are returned as failures
    # without being sent to the upstream service.
    #
    # Usage:
    #   filter = MHV::Prescriptions::OhTransitionRefillFilter.new(current_user, platform: 'web')
    #   allowed_orders, blocked_failures = filter.partition_orders(parsed_orders)
    #
    # Gated by the :mhv_medications_oh_transition_refill_block Flipper flag.
    class OhTransitionRefillFilter
      BLOCKED_PHASES = %w[p4 p5 p6].freeze
      BLOCKED_ERROR_MESSAGE = 'Refill blocked: facility is transitioning to Oracle Health'

      # @param user [User] the current user
      # @param platform [String] 'mobile' or 'web' — used for StatsD metric tagging
      def initialize(user, platform:)
        @user = user
        @platform = platform
      end

      # Partitions orders into allowed and OH-blocked groups.
      # @param orders [Array<Hash>] parsed order hashes with 'stationNumber' and 'id' keys
      # @return [Array(Array<Hash>, Array<Hash>)] [allowed_orders, blocked_failures]
      #   blocked_failures use the standard { id:, error:, station_number: } format
      def partition_orders(orders)
        return [orders, []] unless Flipper.enabled?(:mhv_medications_oh_transition_refill_block, @user)

        phases_map = fetch_phases_map(orders)
        allowed, blocked_failures = split_orders(orders, phases_map)
        track_requested_by_station(orders)
        log_blocked_orders(blocked_failures, orders.size) if blocked_failures.present?

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

      def fetch_phases_map(orders)
        station_numbers = orders.map { |o| o['stationNumber'] }.compact.uniq
        oh_facilities_helper.get_phases_for_station_numbers(station_numbers)
      end

      def split_orders(orders, phases_map)
        orders.each_with_object([[], []]) do |order, (allowed, blocked)|
          phase = phases_map[order['stationNumber'].to_s]
          if BLOCKED_PHASES.include?(phase)
            blocked << { id: order['id'], error: BLOCKED_ERROR_MESSAGE, station_number: order['stationNumber'] }
          else
            allowed << order
          end
        end
      end

      def log_blocked_orders(blocked_failures, total_count)
        blocked_stations = blocked_failures.map { |f| f[:station_number] }.uniq
        Rails.logger.warn(
          'OhTransitionRefillFilter: blocked refill orders for OH-transitioning facilities',
          {
            blocked_count: blocked_failures.size,
            total_count:,
            blocked_stations:
          }
        )
        blocked_stations.each do |station|
          station_count = blocked_failures.count { |f| f[:station_number] == station }
          StatsD.increment('api.uhd.oh_transition.refills.blocked', station_count,
                           tags: ["station_number:#{station}", "platform:#{@platform}"])
        end
      end

      def track_requested_by_station(orders)
        stations = orders.map { |o| o['stationNumber'] }.compact.uniq
        stations.each do |station|
          count = orders.count { |o| o['stationNumber'] == station }
          StatsD.increment('api.uhd.oh_transition.refills.requested_by_station', count,
                           tags: ["station_number:#{station}", "platform:#{@platform}"])
        end
      end

      def oh_facilities_helper
        @oh_facilities_helper ||= MHV::OhFacilitiesHelper::Service.new(@user)
      end
    end
  end
end
