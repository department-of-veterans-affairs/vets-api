# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # V2 Status Mapper - Handles mapping between original MHV statuses and simplified V2 statuses
    # Used by both web and mobile clients for consistent status display
    #
    # V2 Status Categories:
    # - Active: Active prescriptions that can be refilled
    # - In progress: Prescriptions with pending refills
    # - Inactive: Expired, discontinued, or on hold prescriptions
    # - Transferred: Prescriptions transferred to another facility
    # - Status not available: Unknown or unmapped statuses
    module V2StatusMapper
      # V2 Status Categories - Single source of truth for status groupings
      # Maps original MHV statuses to simplified V2 statuses for display
      V2_STATUS_GROUPS = {
        'Active' => ['Active', 'Active: Parked', 'Active: Non-VA'].freeze,
        'In progress' => ['Active: Submitted', 'Active: Refill in Process'].freeze,
        'Inactive' => ['Expired', 'Discontinued', 'Active: On hold'].freeze,
        'Transferred' => ['Transferred'].freeze,
        'Status not available' => ['Unknown'].freeze
      }.freeze

      # Generated mapping from original status to V2 status (case-insensitive lookup)
      # Example: { 'active' => 'Active', 'active: parked' => 'Active', ... }
      ORIGINAL_TO_V2_STATUS_MAPPING = V2_STATUS_GROUPS.each_with_object({}) do |(v2_status, originals), hash|
        originals.each { |original| hash[original.downcase] = v2_status }
      end.freeze

      # Maps a prescription's disp_status to V2 status
      # Can be called on existing prescriptions for status mapping
      #
      # @param prescription [Object] A prescription object with disp_status attribute
      # @return [Object] Prescription with disp_status mapped to V2 value
      def apply_v2_status_mapping(prescription)
        return prescription unless prescription

        current_status = get_disp_status(prescription)
        return prescription if current_status.blank?

        v2_status = map_to_v2_status(current_status)
        set_disp_status(prescription, v2_status)

        prescription
      end

      # Maps an original status to V2 status (case-insensitive)
      #
      # @param original_status [String] Original MHV status value
      # @return [String] V2 status value, or 'Status not available' if no mapping found
      def map_to_v2_status(original_status)
        return 'Status not available' if original_status.blank?

        ORIGINAL_TO_V2_STATUS_MAPPING[original_status.downcase] || 'Status not available'
      end

      # Maps V2 filter values to original status values for filtering
      # Used when filtering prescriptions by V2 status values
      #
      # @param v2_status [String] V2 status value (e.g., 'Inactive')
      # @return [Array<String>] Array of original status values that map to this V2 status
      def original_statuses_for_v2_status(v2_status)
        return [] if v2_status.blank?

        V2_STATUS_GROUPS[v2_status] || []
      end

      # Batch apply V2 status mapping to a collection of prescriptions
      #
      # @param prescriptions [Array] Array of prescription objects
      # @return [Array] Array of prescriptions with V2 status mapping applied
      def apply_v2_status_mapping_to_collection(prescriptions)
        return prescriptions if prescriptions.blank?

        prescriptions.each { |prescription| apply_v2_status_mapping(prescription) }
        prescriptions
      end

      private

      # Gets the disp_status from a prescription (handles Hash and OpenStruct)
      def get_disp_status(prescription)
        if prescription.is_a?(Hash)
          prescription[:disp_status]
        elsif prescription.respond_to?(:disp_status)
          prescription.disp_status
        end
      end

      # Sets the disp_status on a prescription (handles Hash and OpenStruct)
      def set_disp_status(prescription, status)
        if prescription.is_a?(Hash)
          prescription[:disp_status] = status
        elsif prescription.respond_to?(:disp_status=)
          prescription.disp_status = status
        end
      end
    end
  end
end
