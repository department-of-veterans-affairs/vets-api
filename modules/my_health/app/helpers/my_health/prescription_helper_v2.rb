# frozen_string_literal: true

require 'common/exceptions'

module MyHealth
  module PrescriptionHelperV2
    module Filtering
      def collection_resource
        case params[:refill_status]
        when nil
          client.get_all_rxs
        when 'active'
          client.get_active_rxs_with_details
        end
      end

      def filter_non_va_meds(data)
        data.reject { |item| item.prescription_source == 'NV' && item.disp_status != 'Active: Non-VA' }
      end

      def filter_data_by_refill_and_renew(data)
        data.select do |item|
          next true if item.is_refillable
          next true if renewable(item)

          false
        end
      end

      def renewable(item)
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
        
        if disp_status == 'Expired' && expired_date.present? && within_cut_off_date?(expired_date) && not_refillable
          return true
        end

        false
      end

      private

      def within_cut_off_date?(date)
        zero_date = Date.new(0, 1, 1)
        date.present? && date != zero_date && date >= Time.zone.today - 120.days
      end

      module_function :collection_resource,
                      :filter_data_by_refill_and_renew,
                      :filter_non_va_meds,
                      :renewable
    end

    module Sorting
      def apply_sorting(resource, sort_param)
        sorted_resource = case sort_param
                          when 'last-fill-date'
                            last_fill_date_sort(resource)
                          when 'alphabetical-rx-name'
                            alphabetical_sort(resource)
                          else
                            default_sort(resource)
                          end

        sort_metadata = case sort_param
                        when 'last-fill-date'
                          { 'dispensed_date' => 'DESC', 'prescription_name' => 'ASC' }
                        when 'alphabetical-rx-name'
                          { 'prescription_name' => 'ASC', 'dispensed_date' => 'DESC' }
                        else
                          { 'disp_status' => 'ASC', 'prescription_name' => 'ASC', 'dispensed_date' => 'DESC' }
                        end

        (sorted_resource.metadata[:sort] ||= {}).merge!(sort_metadata)
        sorted_resource
      end

      private

      def default_sort(resource)
        resource.records = resource.records.sort do |a, b|
          # 1st sort by status
          status_comparison = (a.disp_status || '') <=> (b.disp_status || '')
          next status_comparison if status_comparison != 0

          # 2nd sort by medication name
          name_comparison = (a.prescription_name || '') <=> (b.prescription_name || '')
          next name_comparison if name_comparison != 0

          # 3rd sort by fill date(sorted_dispensed_date) - newest to oldest
          a_date = get_sorted_dispensed_date(a)
          b_date = get_sorted_dispensed_date(b)

          # move nils to top, then newest to oldest
          null_comparison = (a_date.nil? ? -1 : 0) <=> (b_date.nil? ? -1 : 0)
          next null_comparison if null_comparison != 0

          b_date <=> a_date
        end
        resource
      end

      def last_fill_date_sort(resource)
        empty_dispense_date_meds, filled_meds = partition_meds_by_date(resource.records)

        # Sort filled records order: newest dates first, any ties are sorted in alphabetical order
        filled_meds = filled_meds.sort_by do |med|
          date = get_sorted_dispensed_date(med)
          [
            -date.to_time.to_i,
            med.prescription_name.to_s.downcase
          ]
        end
        
        # Separate empty dispense date meds by va meds and non va meds
        non_va_meds = empty_dispense_date_meds.select { |med| med.prescription_source == 'NV' }
        va_meds = empty_dispense_date_meds.reject { |med| med.prescription_source == 'NV' }
        
        # Sort both arrays alphabetically
        non_va_meds.sort_by! { |med| med.prescription_name.to_s.downcase }
        va_meds.sort_by! { |med| med.prescription_name.to_s.downcase }
        
        # Order: filled meds first, empty va non filled meds second, then empty non filled non va meds last.
        resource.records = filled_meds + va_meds + non_va_meds

        resource
      end

      def alphabetical_sort(resource)
        # First sort by name alphabetically
        sorted_records = resource.records.sort_by { |med| get_medication_name(med) }

        # Then group by name and sort each group by date
        sorted_records = sorted_records.group_by { |med| get_medication_name(med) }.flat_map do |_name, meds|
          # Within each name group, empty dates go first, then sort by date (newest to oldest)
          empty_dates, with_dates = meds.partition { |med| empty_field?(get_sorted_dispensed_date(med)) }
          sorted_with_dates = with_dates.sort_by { |med| -get_sorted_dispensed_date(med).to_time.to_i }

          empty_dates + sorted_with_dates
        end

        resource.records = sorted_records
        resource
      end

      def partition_meds_by_date(records)
        empty_dispense_date_meds = []
        filled_meds = []

        records.each do |med|
          date = get_sorted_dispensed_date(med)
          if empty_field?(date)
            empty_dispense_date_meds << med
          else
            filled_meds << med
          end
        end

        [empty_dispense_date_meds, filled_meds]
      end

      def get_sorted_dispensed_date(med)
        # For UHD prescriptions with dispenses array
        if med.respond_to?(:dispenses) && med.dispenses.present?
          refill_dates = med.dispenses.map { |d| d[:refill_date]&.to_date }.compact
          last_refill_date = refill_dates.max
          return last_refill_date || med.dispensed_date&.to_date
        end
        
        # Fallback to sorted_dispensed_date if available
        if med.respond_to?(:sorted_dispensed_date)
          return med.sorted_dispensed_date
        end
        
        # Final fallback to dispensed_date
        med.dispensed_date&.to_date
      end

      def compare_dispensed_dates(first_date, second_date)
        (second_date || Date.new(0)) <=> (first_date || Date.new(0))
      end

      def get_medication_name(med)
        if med.disp_status == 'Active: Non-VA' && med.prescription_name.nil?
          med.orderable_item || ''
        else
          med.prescription_name || ''
        end
      end

      def get_medication_priority(med)
        return 1 if med.nil? # Handle nil medication object

        sorted_date = get_sorted_dispensed_date(med)
        return 0 if sorted_date.present?
        return 2 if med.prescription_source == 'NV'

        1
      end

      def empty_field?(value)
        value.nil? || value.to_s.strip.empty?
      end

      module_function :apply_sorting
    end
  end
end
