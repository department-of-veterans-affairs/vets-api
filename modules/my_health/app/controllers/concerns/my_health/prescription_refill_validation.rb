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
    # @param orders [Array<Hash>] Array of order hashes with 'id' and 'stationNumber'
    # @param prescription_service_or_list [UnifiedHealthData::Service, Array] Service instance or prescription list
    # @raise [Common::Exceptions::InvalidFieldValue] if validation fails
    def validate_refill_orders!(orders, prescription_service_or_list)
      # Accept either a service (lazy fetch) or pre-loaded prescription list (efficient)
      user_prescriptions = if prescription_service_or_list.respond_to?(:get_prescriptions)
                             # It's a service - fetch prescriptions
                             prescription_service_or_list.get_prescriptions(current_only: false).compact
                           else
                             # It's already a prescription list - use it directly
                             prescription_service_or_list.compact
                           end

      orders.each_with_index do |order, index|
        prescription = user_prescriptions.find do |p|
          p.prescription_id.to_s == order['id'].to_s &&
            p.station_number.to_s == order['stationNumber'].to_s
        end

        unless prescription
          # This catches:
          # 1. Non-existent prescriptions
          # 2. Station number mismatches (including nil/blank station numbers)
          # 3. Invalid station numbers that were set to nil during extraction
          raise Common::Exceptions::InvalidFieldValue.new(
            "orders[#{index}]",
            "Prescription #{order['id']} with station #{order['stationNumber']} " \
            'not found or has invalid station number'
          )
        end
      end
    end
  end
end
