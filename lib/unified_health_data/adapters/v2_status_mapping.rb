# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Module providing V2 status mapping functionality for prescription adapters
    # Maps original VistA/Oracle Health statuses to simplified V2 status groups
    #
    # This mapper is applied at the PrescriptionsAdapter level when the Cerner pilot
    # feature flag is enabled, consolidating status logic in one place for both
    # VistA and Oracle Health prescriptions.
    module V2StatusMapper
      # V2 status groupings - maps V2 status to array of original statuses
      # Based on VA.gov Status Chart mapping requirements
      V2_STATUS_GROUPS = {
        'Active' => [
          'Active',
          'Active: Parked',
          'Active: Non-VA',
          'Active with shipping info'
        ],
        'In progress' => [
          'Active: Submitted',
          'Active: Refill in Process',
          'Pending New Prescription',
          'Pending Renewal'
        ],
        'Inactive' => [
          'Expired',
          'Discontinued',
          'Active: On hold',
          'Active: On Hold'  # Handle case variations
        ],
        'Transferred' => ['Transferred'],
        'Status not available' => ['Unknown']
      }.freeze

      # Reverse mapping - original status (lowercase) to V2 status
      ORIGINAL_TO_V2_STATUS_MAPPING = V2_STATUS_GROUPS.each_with_object({}) do |(v2_status, original_statuses), hash|
        original_statuses.each do |original|
          hash[original.downcase] = v2_status
        end
      end.freeze

      # Maps an original disp_status to its V2 status equivalent
      # @param original_status [String, nil] The original disp_status value
      # @return [String] The V2 status value
      def map_to_v2_status(original_status)
        return 'Status not available' if original_status.nil? || original_status.to_s.strip.empty?

        ORIGINAL_TO_V2_STATUS_MAPPING[original_status.to_s.downcase] || 'Status not available'
      end

      # Returns the array of original statuses that map to a given V2 status
      # @param v2_status [String, nil] The V2 status value
      # @return [Array<String>] Array of original status values
      def original_statuses_for_v2_status(v2_status)
        return [] if v2_status.nil?

        V2_STATUS_GROUPS[v2_status] || []
      end

      # Applies V2 status mapping to a single prescription object or hash
      # @param prescription [Object, Hash] A prescription object or hash with disp_status attribute
      # @return [Object, Hash] The same prescription with mapped disp_status
      def apply_v2_status_mapping(prescription)
        if prescription.is_a?(Hash)
          # Handle hash-based prescriptions (Vista)
          original_status = prescription[:disp_status]
          return prescription if original_status.nil? || original_status.to_s.empty?

          prescription[:disp_status] = map_to_v2_status(original_status)
        elsif prescription.respond_to?(:disp_status) && prescription.respond_to?(:disp_status=)
          # Handle object-based prescriptions (OpenStruct/Oracle)
          return prescription if prescription.disp_status.nil? || prescription.disp_status.to_s.empty?

          prescription.disp_status = map_to_v2_status(prescription.disp_status)
        end
        prescription
      end

      # Applies V2 status mapping to a collection of prescriptions
      # @param prescriptions [Array] Array of prescription objects
      # @return [Array] The same array with all prescriptions mapped
      def apply_v2_status_mapping_to_collection(prescriptions)
        prescriptions.each { |rx| apply_v2_status_mapping(rx) }
      end
    end
  end
end