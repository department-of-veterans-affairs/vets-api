# frozen_string_literal: true

require_relative 'oracle_health_prescription_adapter'
require_relative 'v2_status_mapper'

module UnifiedHealthData
  module Adapters
    # Combines prescriptions from multiple sources and applies V2 status mapping
    # This is the SINGLE point where V2 status mapping should be invoked
    class PrescriptionsAdapter
      include V2StatusMapper

      def initialize(use_v2_statuses: false)
        @use_v2_statuses = use_v2_statuses
        @oracle_adapter = OracleHealthPrescriptionAdapter.new
      end

      # Combines and normalizes prescriptions from all sources
      # V2 status mapping is applied HERE - single point of truth
      #
      # @param oracle_resources [Array] Oracle Health FHIR resources
      # @param vista_prescriptions [Array] VistA prescription objects (already parsed)
      # @return [Array<UnifiedHealthData::Prescription>] Combined, normalized prescriptions
      def combine_prescriptions(oracle_resources: [], vista_prescriptions: [])
        prescriptions = []

        # Parse Oracle Health prescriptions
        oracle_resources.each do |resource|
          prescription = @oracle_adapter.parse(resource)
          prescriptions << prescription if prescription
        end

        # Add VistA prescriptions (already parsed)
        prescriptions.concat(vista_prescriptions)

        # Apply V2 status mapping ONCE at this level
        apply_v2_status_mapping_to_collection(prescriptions) if @use_v2_statuses

        prescriptions
      end

      # Maps V2 filter values to original status values for filtering
      # Used by controllers to translate V2 filters before querying
      #
      # @param filters [Array<String>] V2 status filter values
      # @return [Array<String>] Original status values (lowercase)
      def map_v2_filters_to_original(filters)
        filters.flat_map do |filter|
          original_statuses = original_statuses_for_v2_status(filter.strip.titleize)
          if original_statuses.any?
            original_statuses.map(&:downcase)
          else
            # Try exact match for V2 status name with different casing
            v2_status_match = V2_STATUS_GROUPS.keys.find { |k| k.downcase == filter.strip.downcase }
            if v2_status_match
              original_statuses_for_v2_status(v2_status_match).map(&:downcase)
            else
              [filter.downcase]
            end
          end
        end.uniq
      end
    end
  end
end
