# frozen_string_literal: true

require 'unified_health_data/service'
require 'unique_user_events'

module MyHealth
  module V3
    # V3 Prescriptions Controller - Focused on refillable prescriptions for widget/modal use
    class PrescriptionsController < ApplicationController
      service_tag 'mhv-prescriptions'

      # GET /my_health/v3/prescriptions/refillable
      # Returns a minimal list of refillable prescriptions for UI widgets/modals
      # Only includes essential fields needed for prescription selection
      def refillable_prescriptions
        return unless validate_feature_flag

        prescriptions = service.get_prescriptions(current_only: false).compact
        refillable = filter_refillable_prescriptions(prescriptions)

        log_prescriptions_access

        render json: MyHealth::V3::RefillablePrescriptionSerializer.new(refillable)
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(current_user)
      end

      def validate_feature_flag
        return true if Flipper.enabled?(:mhv_medications_v3_refillable_endpoint, current_user)

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
        false
      end

      # Filter prescriptions to only those that are refillable
      # A prescription is refillable if:
      # - is_refillable is true
      # - disp_status indicates it can be refilled
      # - Has remaining refills
      def filter_refillable_prescriptions(prescriptions)
        prescriptions.select do |prescription|
          prescription.respond_to?(:is_refillable) &&
            prescription.is_refillable &&
            prescription.respond_to?(:refill_remaining) &&
            prescription.refill_remaining.to_i.positive?
        end
      end

      def log_prescriptions_access
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
        )
      end
    end
  end
end
