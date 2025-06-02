# frozen_string_literal: true

require 'common/exceptions'

module MyHealth
  module PrescriptionHelper
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
        disp_status = item.disp_status
        refill_history_expired_date = item.rx_rf_records&.dig(0, :expiration_date)&.to_date
        expired_date = refill_history_expired_date || item.expiration_date&.to_date
        not_refillable = ['false'].include?(item.is_refillable.to_s)
        if item.refill_remaining.to_i.zero? && not_refillable
          return true if disp_status&.downcase == 'active'
          return true if disp_status&.downcase == 'active: parked' && !item.rx_rf_records.all?(&:empty?)
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
                      :sort_by,
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
          a_date = a.sorted_dispensed_date || Date.new(0, 1, 1)
          b_date = b.sorted_dispensed_date || Date.new(0, 1, 1)

          # Handle nulls first, then newest to oldest
          null_comparison = (a_date.nil? ? -1 : 0) <=> (b_date.nil? ? -1 : 0)
          next null_comparison if null_comparison != 0

          b_date <=> a_date
        end
        resource
      end

      def last_fill_date_sort(resource)
        null_dispensed_dates = resource.records.select { |med| med.sorted_dispensed_date.nil? }
        non_null_dispensed_dates = resource.records.reject { |med| med.sorted_dispensed_date.nil? }

        # Sort non-null dispensed dates
        non_null_dispensed_dates.sort_by! do |first_med, second_med|
          first_med_priority = get_medication_priority(first_med)
          second_med_priority = get_medication_priority(second_med)

          priority_comparison = first_med_priority <=> second_med_priority
          next priority_comparison if priority_comparison != 0

          case first_med_priority
          when 0 # Filled medications
            # Compare by fill date - newest first
            date_comparison = compare_dispensed_dates(first_med.sorted_dispensed_date, second_med.sorted_dispensed_date)
            next date_comparison if date_comparison != 0

            # If same date, sort by name
            (first_med.prescription_name || '') <=> (second_med.prescription_name || '')
          when 1, 2 # Not-yet-filled and Non-VA medications
            # Sort alphabetically by name
            (first_med.prescription_name || '') <=> (second_med.prescription_name || '')
          end
        end

        resource.records = null_dispensed_dates + non_null_dispensed_dates
        resource
      end

      def alphabetical_sort(resource)
        resource.records = resource.records.sort do |first_med, second_med|
          # First compare by medication names
          first_name = get_medication_name(first_med)
          second_name = get_medication_name(second_med)
          name_comparison = first_name <=> second_name
          next name_comparison if name_comparison != 0

          # If names are same, sort by fill date -nnewest first
          first_fill_date = first_med.sorted_dispensed_date || Date.new(0)
          second_fill_date = second_med.sorted_dispensed_date || Date.new(0)
          second_fill_date <=> first_fill_date
        end
        resource
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

        return 0 if med.sorted_dispensed_date.present?
        return 2 if med.prescription_source == 'NV'

        1
      end

      module_function :apply_sorting
    end
  end
end
