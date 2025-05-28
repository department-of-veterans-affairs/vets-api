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
        data.reject { |item| item[:prescription_source] == 'NV' && item[:disp_status] != 'Active: Non-VA' }
      end

      def sort_by(resource, sort_params)
        sort_orders = sort_params.map { |param| param.to_s.start_with?('-') }
        resource.data = resource.data.sort do |a, b|
          comparison = 0
          sort_params.each_with_index do |field, index|
            is_descending = sort_orders[index]
            field_a, field_b = populate_sort_vars(field, a, b, is_descending)
            comparison = compare_fields(field_a, field_b, is_descending)
            break if !comparison.zero? || field.nil?
          end
          comparison
        end
        sort_params.each_with_index do |field, index|
          field_camelcase = field.sub(/^-/, '').gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
          if field.present?
            (resource.metadata[:sort] ||= {}).merge!({ field_camelcase => sort_orders[index] ? 'DESC' : 'ASC' })
          end
        end
        resource
      end

      def compare_fields(field_a, field_b, is_descending)
        if field_a > field_b
          is_descending ? -1 : 1
        elsif field_a < field_b
          is_descending ? 1 : -1
        else
          0
        end
      end

      def populate_sort_vars(field, a, b, is_descending)
        if field.nil?
          [nil, nil]
        else
          [get_field_data(field, a, is_descending), get_field_data(field, b, is_descending)]
        end
      end

      def get_field_data(field, data, is_descending)
        case field
        when /dispensed_date/
          if data[:sorted_dispensed_date].nil?
            is_descending ? Date.new(9999, 12, 31) : Date.new(0, 1, 1)
          else
            data[:sorted_dispensed_date]
          end
        when 'prescription_name'
          if data[:disp_status] == 'Active: Non-VA' && data[:prescription_name].nil?
            data[:orderable_item]
          elsif !data[:prescription_name].nil?
            data[:prescription_name]
          else
            '~'
          end
        when 'disp_status'
          data[:disp_status]
        else
          data[field.sub(/^-/, '')]
        end
      end

      def filter_data_by_refill_and_renew(data)
        data.select do |item|
          next true if item[:is_refillable]
          next true if renewable(item)

          false
        end
      end

      def renewable(item)
        disp_status = item[:disp_status]
        refill_history_expired_date = item[:rx_rf_records]&.[](0)&.[](1)&.[](0)&.[](:expiration_date)&.to_date
        expired_date = refill_history_expired_date || item[:expiration_date]&.to_date
        not_refillable = ['false'].include?(item.is_refillable.to_s)
        if item[:refill_remaining].to_i.zero? && not_refillable
          return true if disp_status&.downcase == 'active'
          return true if disp_status&.downcase == 'active: parked' && !item[:rx_rf_records].all?(&:empty?)
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
                          when 'alphabetical'
                            alphabetical_sort(resource)
                          else
                            default_sort(resource)
                          end

        sort_metadata = case sort_param
                        when 'last-fill-date'
                          { 'dispensedDate' => 'DESC', 'prescriptionName' => 'ASC' }
                        when 'alphabetical'
                          { 'prescriptionName' => 'ASC', 'dispensedDate' => 'DESC' }
                        else
                          { 'dispStatus' => 'ASC', 'prescriptionName' => 'ASC', 'dispensedDate' => 'DESC' }
                        end

        (sorted_resource.metadata[:sort] ||= {}).merge!(sort_metadata)
        sorted_resource
      end

      private

      def default_sort(resource)
        resource.data = resource.data.sort do |a, b|
          # 1st sort by status
          status_comparison = (a[:disp_status] || '') <=> (b[:disp_status] || '')
          next status_comparison if status_comparison != 0

          # 2nd sort by medication name
          name_comparison = (a[:prescription_name] || '') <=> (b[:prescription_name] || '')
          next name_comparison if name_comparison != 0

          # 3rd sort by fill date(sorted_dispensed_date) - newest to oldest
          b_date = b[:sorted_dispensed_date] || Date.new(0)
          a_date = a[:sorted_dispensed_date] || Date.new(0)
          b_date <=> a_date
        end
        resource
      end

      def last_fill_date_sort(resource)
        resource.data = resource.data.sort do |first_med, second_med|
          # Determine priority level for each medication
          first_med_priority = get_medication_priority(first_med)
          second_med_priority = get_medication_priority(second_med)

          # Compare priorities first
          priority_comparison = first_med_priority <=> second_med_priority
          next priority_comparison if priority_comparison != 0

          case first_med_priority
          when 0 # Filled medications
            # Compare by fill date - newest first
            first_fill_date = first_med[:sorted_dispensed_date] || Date.new(0)
            second_fill_date = second_med[:sorted_dispensed_date] || Date.new(0)
            date_comparison = second_fill_date <=> first_fill_date
            next date_comparison if date_comparison != 0

            # If same date, sort by name
            (first_med[:prescription_name] || '') <=> (second_med[:prescription_name] || '')
          when 1, 2 # Not-yet-filled and Non-VA medications
            # Sort alphabetically by name
            (first_med[:prescription_name] || '') <=> (second_med[:prescription_name] || '')
          end
        end
        resource
      end

      def alphabetical_sort(resource)
        resource.data = resource.data.sort do |first_med, second_med|
          # First compare by medication names
          first_name = get_medication_name(first_med)
          second_name = get_medication_name(second_med)
          name_comparison = first_name <=> second_name
          next name_comparison if name_comparison != 0

          # If names are same, sort by fill date -nnewest first
          first_fill_date = first_med[:sorted_dispensed_date] || Date.new(0)
          second_fill_date = second_med[:sorted_dispensed_date] || Date.new(0)
          second_fill_date <=> first_fill_date
        end
        resource
      end

      def get_medication_name(med)
        if med[:disp_status] == 'Active: Non-VA' && med[:prescription_name].nil?
          med[:orderable_item] || ''
        else
          med[:prescription_name] || ''
        end
      end

      def get_medication_priority(med)
        return 0 if med[:sorted_dispensed_date].present? # Filled meds get top priority
        return 2 if med[:prescription_source] == 'NV'    # Non-VA meds get lowest priority

        1 # Not-yet-filled meds in middle
      end

      module_function :apply_sorting
    end
  end
end
