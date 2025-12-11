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
          next true if check_renewable(item)

          false
        end
      end

      # Check if item is renewable using the is_renewable attribute
      # from the unified health data API (V2/Cerner pilot)
      # @param item [Object] Prescription item with is_renewable attribute
      # @return [Boolean] Whether the item is renewable
      def check_renewable(item)
        item.respond_to?(:is_renewable) && item.is_renewable == true
      end

      # Apply custom filters that require computed logic (not direct attribute filtering)
      # Handles filters like isRenewable and shipped that aren't direct model attributes
      # @param data [Array] Array of prescription items
      # @param filter_params [Hash] Filter parameters from request
      # @return [Array] Filtered data
      def apply_custom_filters(data, filter_params)
        return data if filter_params.blank?

        result = data
        result = apply_renewable_filter(result, filter_params[:isRenewable]) if filter_params[:isRenewable]
        result = apply_shipped_filter(result, filter_params[:shipped]) if filter_params[:shipped]
        result
      end

      private

      def apply_renewable_filter(data, filter_config)
        return data unless filter_config[:eq]

        filter_value = ActiveModel::Type::Boolean.new.cast(filter_config[:eq])
        data.select { |item| check_renewable(item) == filter_value }
      end

      def apply_shipped_filter(data, filter_config)
        return data unless filter_config[:eq]

        filter_value = ActiveModel::Type::Boolean.new.cast(filter_config[:eq])
        data.select do |item|
          # Shipped = Active disp_status AND is_trackable
          item_is_active = item.respond_to?(:disp_status) && item.disp_status == 'Active'
          item_trackable = item.respond_to?(:is_trackable) && item.is_trackable
          item_shipped = item_is_active && item_trackable
          item_shipped == filter_value
        end
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

      def partition_meds_by_date(records)
        records.partition { |med| empty_field?(get_sorted_dispensed_date(med)) }.reverse
      end

      def get_sorted_dispensed_date(med)
        return extract_last_refill_date(med) if med.respond_to?(:dispenses) && med.dispenses.present?
        return med.sorted_dispensed_date if med.respond_to?(:sorted_dispensed_date)

        med.dispensed_date&.to_date
      end

      def extract_last_refill_date(med)
        refill_dates = med.dispenses.map { |d| d[:refill_date]&.to_date }.compact
        refill_dates.max || med.dispensed_date&.to_date
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

      module_function :apply_sorting
    end
  end
end
