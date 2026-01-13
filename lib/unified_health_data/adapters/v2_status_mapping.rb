# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Module providing V2 status mapping functionality for prescription adapters
    # Maps original VistA/Oracle Health statuses to simplified V2 status groups
    #
    # This mapping is applied at the PrescriptionsAdapter level when the
    # mhv_medications_v2_status_mapping feature flag is enabled, consolidating
    # status logic in one place for both VistA and Oracle Health prescriptions.
    #
    # Expects prescription objects that respond to :disp_status, :disp_status=, and optionally :refill_status
    # (e.g., UnifiedHealthData::Prescription or OpenStruct)
    module V2StatusMapping
      # Default status when original status is nil, empty, or unrecognized
      DEFAULT_V2_STATUS = 'Status not available'

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
          'Active: On hold'
        ],
        'Transferred' => ['Transferred'],
        DEFAULT_V2_STATUS => ['Unknown']
      }.freeze

      # Reverse mapping - original status (lowercase) to V2 status
      ORIGINAL_TO_V2_STATUS_MAPPING = V2_STATUS_GROUPS.each_with_object({}) do |(v2_status, original_statuses), hash|
        original_statuses.each do |original|
          hash[original.downcase] = v2_status
        end
      end.freeze

      # Mapping from refill_status to disp_status
      # Used when disp_status is nil/empty but refill_status is present
      REFILL_STATUS_TO_DISP_STATUS = {
        'active' => 'Active',
        'refillinprocess' => 'Active: Refill in Process',
        'submitted' => 'Active: Submitted',
        'hold' => 'Active: On hold',
        'providerhold' => 'Active: On hold',
        'expired' => 'Expired',
        'discontinued' => 'Discontinued',
        'transferred' => 'Transferred',
        'unknown' => 'Unknown'
      }.freeze

      # Maps an original disp_status to its V2 status equivalent
      # @param original_status [String, nil] The original disp_status value
      # @return [String] The V2 status value
      def map_to_v2_status(original_status)
        return DEFAULT_V2_STATUS if original_status.nil? || original_status.to_s.strip.empty?

        ORIGINAL_TO_V2_STATUS_MAPPING[original_status.to_s.downcase] || DEFAULT_V2_STATUS
      end

      # Returns the array of original statuses that map to a given V2 status
      # @param v2_status [String, nil] The V2 status value
      # @return [Array<String>] Array of original status values
      def original_statuses_for_v2_status(v2_status)
        return [] if v2_status.nil?

        V2_STATUS_GROUPS[v2_status] || []
      end

      # Applies V2 status mapping to a single prescription object
      # If disp_status is nil/empty but refill_status is present, first derives disp_status from refill_status
      # Then maps the disp_status to V2 format
      # @param prescription [Object] A prescription object with disp_status/disp_status= accessors
      #   (e.g., UnifiedHealthData::Prescription, OpenStruct)
      # @return [Object] The same prescription with mapped disp_status
      def apply_v2_status_mapping(prescription)
        return prescription unless prescription.respond_to?(:disp_status) && prescription.respond_to?(:disp_status=)

        derive_disp_status_from_refill_status(prescription)

        return prescription if prescription.disp_status.blank?

        prescription.disp_status = map_to_v2_status(prescription.disp_status)
        prescription
      end

      # Applies V2 status mapping to a collection of prescriptions
      # @param prescriptions [Array] Array of prescription objects
      # @return [Array] The same array with all prescriptions mapped
      def apply_v2_status_mapping_to_all(prescriptions)
        return prescriptions unless prescriptions.is_a?(Array)

        prescriptions.each { |rx| apply_v2_status_mapping(rx) }
        prescriptions
      end

      private

      # Derives disp_status from refill_status if disp_status is blank
      # @param prescription [Object] A prescription object
      def derive_disp_status_from_refill_status(prescription)
        return if prescription.disp_status.present?
        return unless prescription.respond_to?(:refill_status) && prescription.refill_status.present?

        refill_status = prescription.refill_status.to_s.downcase
        prescription.disp_status = REFILL_STATUS_TO_DISP_STATUS[refill_status] || 'Unknown'
      end
    end
  end
end
