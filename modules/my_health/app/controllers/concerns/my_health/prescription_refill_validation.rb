# frozen_string_literal: true

# Shared concern for validating prescription refill orders across controllers
# Ensures that refill requests only include prescriptions that:
# - Belong to the current user
# - Have valid, non-blank station numbers
# - Match both prescription ID and station number
#
# Usage:
#   class MyController < ApplicationController
#     include MyHealth::PrescriptionRefillValidation
#
#     def refill
#       parsed_orders = orders
#       validate_refill_orders!(parsed_orders, service)
#       # ... proceed with refill
#     end
#   end
module MyHealth
  module PrescriptionRefillValidation
    extend ActiveSupport::Concern

    private

    # Validates that refill orders match actual prescriptions with valid station numbers
    # Raises InvalidFieldValue if any order references a prescription that doesn't exist
    # or has an invalid/missing station number
    #
    # PERFORMANCE NOTE: This method makes an external API call via get_prescriptions when
    # passed a service object. For optimal performance, pass a pre-loaded prescription list
    # if prescriptions have already been fetched (e.g., to display to the user). This avoids
    # duplicate API calls and reduces latency on refill requests.
    #
    # @param orders [Array<Hash>] Array of order hashes with 'id' and 'stationNumber'
    # @param prescription_service_or_list [UnifiedHealthData::Service, Array]
    #   - Service instance (lazy fetch, makes API call - use when prescriptions not yet loaded)
    #   - Pre-loaded prescription array (efficient - use when prescriptions already fetched)
    # @raise [Common::Exceptions::InvalidFieldValue] if validation fails
    #
    # @example With service (makes API call)
    #   validate_refill_orders!(parsed_orders, service)
    #
    # @example With pre-loaded prescriptions (efficient, no API call)
    #   all_prescriptions = service.get_prescriptions(current_only: false)
    #   validate_refill_orders!(parsed_orders, all_prescriptions)
    #
    def validate_refill_orders!(orders, prescription_service_or_list)
      # Accept either a service (lazy fetch) or pre-loaded prescription list (efficient)
      user_prescriptions = if prescription_service_or_list.respond_to?(:get_prescriptions)
                             # It's a service - fetch prescriptions (makes external API call)
                             prescription_service_or_list.get_prescriptions(current_only: false).compact
                           else
                             # It's already a prescription list - use it directly (no API call)
                             prescription_service_or_list.compact
                           end

      orders.each_with_index do |order, index|
        # NOTE: order['id'] and order['stationNumber'] are already validated to be present
        # by the orders() method in the controller, but we defensively check prescriptions
        prescription = find_matching_prescription(user_prescriptions, order)

        next if prescription

        # Log detailed info for debugging, then raise error with generic message
        log_validation_failure(order, index)
        raise_validation_error(index)
      end
    end

    # Finds a prescription matching the order's ID and station number
    # Only matches prescriptions with valid (non-blank) identifiers
    #
    # @param prescriptions [Array] List of prescription objects
    # @param order [Hash] Order hash with 'id' and 'stationNumber'
    # @return [Object, nil] Matching prescription or nil if not found
    def find_matching_prescription(prescriptions, order)
      prescriptions.find do |p|
        p.prescription_id.present? && p.station_number.present? &&
          p.prescription_id.to_s == order['id'].to_s &&
          p.station_number.to_s == order['stationNumber'].to_s
      end
    end

    # Logs validation failure details for debugging
    # Includes order index, prescription ID, and station number
    #
    # @param order [Hash] The failed order
    # @param index [Integer] Order position in the array
    def log_validation_failure(order, index)
      Rails.logger.warn(
        message: 'Refill validation failed',
        order_index: index,
        prescription_id: order['id'],
        station_number: order['stationNumber'],
        service: 'prescription_refill_validation'
      )
    end

    # Raises validation error with generic user-facing message
    # This catches multiple failure scenarios:
    # 1. Non-existent prescriptions
    # 2. Prescriptions with blank/nil prescription_id or station_number
    # 3. Station number mismatches
    # 4. Invalid station numbers that were set to nil during extraction
    #
    # @param index [Integer] Order position in the array
    # @raise [Common::Exceptions::InvalidFieldValue]
    def raise_validation_error(index)
      raise Common::Exceptions::InvalidFieldValue.new(
        "orders[#{index}]",
        'Prescription not found or has invalid station number'
      )
    end
  end
end
