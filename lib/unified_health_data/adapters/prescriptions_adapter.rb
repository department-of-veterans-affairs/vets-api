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

      # Parses combined records from UHD API response
      # V2 status mapping is applied HERE - single point of truth
      #
      # @param combined_records [Array] Combined Oracle Health and VistA records from UHD API
      # @param current_only [Boolean] When true, filters out old discontinued/expired medications
      # @return [Array<Hash>] Parsed and normalized prescriptions
      def parse(combined_records, current_only: false)
        prescriptions = []

        combined_records.each do |record|
          source = record['source']
          resource = record['resource']

          prescription = if source == 'oracle-health'
                           @oracle_adapter.parse(resource)
                         else
                           # VistA prescriptions come pre-parsed from UHD API
                           parse_vista_prescription(resource)
                         end

          prescriptions << prescription if prescription
        end

        # Apply current_only filtering if requested
        prescriptions = filter_current_prescriptions(prescriptions) if current_only

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

      private

      # Parse VistA prescription from UHD API response
      # VistA prescriptions come with a different structure than Oracle Health
      #
      # @param resource [Hash] VistA prescription resource from UHD API
      # @return [Hash, nil] Parsed prescription or nil if invalid
      def parse_vista_prescription(resource)
        return nil unless resource

        build_vista_prescription_hash(resource)
      end

      def build_vista_prescription_hash(resource)
        base_vista_fields(resource).merge(additional_vista_fields(resource))
      end

      def base_vista_fields(resource)
        {
          id: resource['id'],
          type: 'Prescription',
          prescription_id: resource['prescription_id'] || resource['id'],
          prescription_number: resource['prescription_number'],
          prescription_name: resource['prescription_name'],
          refill_status: resource['refill_status'],
          refill_submit_date: resource['refill_submit_date'],
          refill_date: resource['refill_date'],
          refill_remaining: resource['refill_remaining'],
          facility_name: resource['facility_name'],
          ordered_date: resource['ordered_date'],
          quantity: resource['quantity']
        }
      end

      def additional_vista_fields(resource)
        {
          expiration_date: resource['expiration_date'],
          dispensed_date: resource['dispensed_date'],
          station_number: resource['station_number'],
          is_refillable: resource['is_refillable'],
          is_trackable: resource['is_trackable'],
          prescription_source: resource['prescription_source'] || 'VA',
          disp_status: resource['disp_status'],
          cmop_division_phone: resource['cmop_division_phone'],
          cmop_ndc_number: resource['cmop_ndc_number'],
          instructions: resource['sig'] || resource['instructions'],
          tracking: resource['tracking'] || [],
          dispenses: resource['dispenses'] || []
        }
      end

      # Filters prescriptions to only include "current" medications
      # Excludes discontinued/expired medications older than 180 days
      #
      # @param prescriptions [Array<Hash>] All prescriptions
      # @return [Array<Hash>] Filtered prescriptions
      def filter_current_prescriptions(prescriptions)
        cutoff_date = 180.days.ago

        prescriptions.select do |rx|
          disp_status = rx[:disp_status]&.downcase

          # Always include active prescriptions
          next true if disp_status&.start_with?('active')

          # For discontinued/expired, check the date
          if %w[discontinued expired].include?(disp_status)
            # Use dispensed_date or ordered_date for comparison
            date_str = rx[:dispensed_date] || rx[:ordered_date]
            next true if date_str.blank?

            begin
              prescription_date = Time.zone.parse(date_str)
              prescription_date > cutoff_date
            rescue ArgumentError
              true # Include if date parsing fails
            end
          else
            true # Include other statuses
          end
        end
      end
    end
  end
end
