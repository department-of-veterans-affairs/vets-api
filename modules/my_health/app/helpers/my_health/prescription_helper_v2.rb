# frozen_string_literal: true

require 'common/exceptions'

module MyHealth
  module PrescriptionHelperV2
    module Filtering
      def collection_resource
        case params[:refill_status]
        when 'active'
          client.get_active_rxs_with_details
        else
          client.get_all_rxs
        end
      end

      def filter_data_by_refill_and_renew(data)
        data.select do |item|
          next true if item.is_refillable
          next true if renewable(item)

          false
        end
      end

      def renewable(item)
        return item.is_renewable if item.respond_to?(:is_renewable) && !item.is_renewable.nil?

        # UHD prescriptions have disp_status attribute
        return false unless item.respond_to?(:disp_status)

        disp_status = item.disp_status

        # For UHD prescriptions, check dispenses array for expiration date
        refill_history_expired_date = if item.respond_to?(:dispenses) && item.dispenses.present?
                                        item.dispenses.first&.dig(:expiration_date)&.to_date
                                      end

        expired_date = refill_history_expired_date || item.expiration_date&.to_date
        not_refillable = ['false'].include?(item.is_refillable.to_s)

        if item.refill_remaining.to_i.zero? && not_refillable
          return true if disp_status&.downcase == 'active'

          # Check dispenses for non-empty records
          has_dispenses = item.respond_to?(:dispenses) && item.dispenses.present? && !item.dispenses.all?(&:empty?)

          return true if disp_status&.downcase == 'active: parked' && has_dispenses
        end

        # NOTE: When V2StatusMapping is enabled, "Expired" is mapped to "Inactive"
        expired_or_inactive = %w[Expired Inactive].include?(disp_status)
        if expired_or_inactive && expired_date.present? && within_cut_off_date?(expired_date) && not_refillable
          return true
        end

        false
      end

      private

      def within_cut_off_date?(date)
        zero_date = Date.new(0, 1, 1)
        date.present? && date != zero_date && date >= Time.zone.today - 120.days
      end
    end

    module Sorting
      def apply_sorting(resource, sort_param)
        sorted_resource = sort_resource_by_param(resource, sort_param)
        sort_metadata = build_sort_metadata(sort_param)
        (sorted_resource.metadata[:sort] ||= {}).merge!(sort_metadata)
        sorted_resource
      end

      def sort_resource_by_param(resource, param)
        return last_fill_date_sort(resource) if param == 'last-fill-date'
        return alphabetical_sort(resource) if param == 'alphabetical-rx-name'

        default_sort(resource)
      end

      def build_sort_metadata(sort_param)
        case sort_param
        when 'last-fill-date'
          { 'dispensed_date' => 'DESC', 'prescription_name' => 'ASC' }
        when 'alphabetical-rx-name'
          { 'prescription_name' => 'ASC', 'dispensed_date' => 'DESC' }
        else
          { 'disp_status' => 'ASC', 'prescription_name' => 'ASC', 'dispensed_date' => 'DESC' }
        end
      end

      private

      def default_sort(resource)
        resource.records = resource.records.sort { |a, b| compare_medications(a, b) }
        resource
      end

      def compare_medications(a, b)
        status_comparison = (a.disp_status || '') <=> (b.disp_status || '')
        return status_comparison if status_comparison != 0

        name_comparison = (a.prescription_name || '') <=> (b.prescription_name || '')
        return name_comparison if name_comparison != 0

        compare_by_fill_date(a, b)
      end

      def compare_by_fill_date(a, b)
        a_date = get_sorted_dispensed_date(a)
        b_date = get_sorted_dispensed_date(b)
        null_comparison = (a_date.nil? ? -1 : 0) <=> (b_date.nil? ? -1 : 0)
        return null_comparison if null_comparison != 0

        b_date <=> a_date
      end

      def last_fill_date_sort(resource)
        empty_dispense_date_meds, filled_meds = partition_meds_by_date(resource.records)
        filled_meds = sort_filled_meds_by_date(filled_meds)
        va_meds, non_va_meds = partition_and_sort_empty_meds(empty_dispense_date_meds)
        resource.records = filled_meds + va_meds + non_va_meds
        resource
      end

      def sort_filled_meds_by_date(filled_meds)
        filled_meds.sort_by do |med|
          date = get_sorted_dispensed_date(med)
          [-date&.to_time.to_i, med.prescription_name.to_s.downcase]
        end
      end

      def partition_and_sort_empty_meds(empty_meds)
        non_va = empty_meds.select { |med| med.prescription_source == 'NV' }
        va = empty_meds.reject { |med| med.prescription_source == 'NV' }
        [va.sort_by { |med| med.prescription_name.to_s.downcase },
         non_va.sort_by { |med| med.prescription_name.to_s.downcase }]
      end

      def alphabetical_sort(resource)
        sorted_records = resource.records.sort_by { |med| get_medication_name(med) }
        sorted_records = sort_grouped_by_name(sorted_records)
        resource.records = sorted_records
        resource
      end

      def sort_grouped_by_name(records)
        records.group_by { |med| get_medication_name(med) }.flat_map do |_name, meds|
          sort_meds_by_date_within_group(meds)
        end
      end

      def sort_meds_by_date_within_group(meds)
        empty_dates, with_dates = meds.partition { |med| empty_field?(get_sorted_dispensed_date(med)) }
        sorted_with_dates = with_dates.sort_by { |med| -get_sorted_dispensed_date(med).to_time.to_i }
        empty_dates + sorted_with_dates
      end

      # Partitions prescriptions into those with dates and those without dates.
      # Returns [empty_date_meds, filled_meds] - meds without dates first, meds with dates second.
      # This matches the expected destructuring in last_fill_date_sort.
      def partition_meds_by_date(records)
        records.partition { |med| empty_field?(get_sorted_dispensed_date(med)) }
      end

      def get_sorted_dispensed_date(med)
        return extract_last_fill_date(med) if med.respond_to?(:dispenses) && med.dispenses.present?
        return med.sorted_dispensed_date if med.respond_to?(:sorted_dispensed_date)

        med.dispensed_date&.to_date
      end

      # Extracts the most recent fill date from a prescription's dispenses.
      # Both Vista and Oracle Health adapters now provide dispensed_date in dispenses:
      # - Vista: dispensed_date from VistA dispensedDate field
      # - Oracle Health: dispensed_date from FHIR whenHandedOver field
      def extract_last_fill_date(med)
        dispensed_dates = med.dispenses.filter_map { |d| d[:dispensed_date]&.to_date }
        dispensed_dates.max || med.dispensed_date&.to_date
      end

      def get_medication_name(med)
        if med.disp_status == 'Active: Non-VA' && med.prescription_name.nil?
          med.orderable_item || ''
        else
          med.prescription_name || ''
        end
      end

      def empty_field?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
