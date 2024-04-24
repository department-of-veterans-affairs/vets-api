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

      def sort_by(data, field1, field2 = nil, field3 = nil)
        data.sort do |a, b|
          field1_a, field1_b = populate_sort_vars(field1, a, b)
          field2_a, field2_b = populate_sort_vars(field2, a, b)
          field3_a, field3_b = populate_sort_vars(field3, a, b)
          field1_descending, field2_descending, field3_descending = get_sort_order(field1, field2, field3)

          comparison = compare_fields(field1_a, field1_b, field1_descending)
          comparison = compare_fields(field2_a, field2_b, field2_descending) if comparison.zero? && field2.present?
          comparison = compare_fields(field3_a, field3_b, field3_descending) if comparison.zero? && field3.present?

          comparison
        end
      end

      def get_sort_order(field1, field2, field3)
        field1_descending = field1.to_s.start_with?('-')
        field2_descending = field2.to_s.start_with?('-')
        field3_descending = field3.to_s.start_with?('-')
        [field1_descending, field2_descending, field3_descending]
      end

      def compare_fields(field_a, field_b, descending)
        if field_a > field_b
          descending ? -1 : 1
        elsif field_a < field_b
          descending ? 1 : -1
        else
          0
        end
      end

      def populate_sort_vars(field, a, b)
        if field.nil?
          [nil, nil]
        else
          [get_field_data(field, a), get_field_data(field, b)]
        end
      end

      def get_field_data(field, data)
        case field
        when /dispensed_date/
          data[:sorted_dispensed_date]
        when 'prescription_name'
          if data.disp_status != 'Active: Non-VA' || data.prescription_name
            data[:prescription_name]
          else
            data[:orderable_item]
          end
        else
          data[:disp_status]
        end
      end

      def filter_data_by_refill_and_renew(data)
        data.select do |item|
          disp_status = item[:disp_status]
          refill_history_expired_date = item[:rx_rf_records]&.[](0)&.[](1)&.[](0)&.[](:expiration_date)&.to_date
          expired_date = refill_history_expired_date || item[:expiration_date]&.to_date
          next true if ['Active', 'Active: Parked'].include?(disp_status)
          if disp_status == 'Expired' && expired_date.present? && valid_date_within_cut_off_date?(expired_date)
            next true
          end

          false
        end
      end

      private

      def valid_date_within_cut_off_date?(date)
        cut_off_date = Time.zone.today - 120.days
        zero_date = Date.new(0, 1, 1)
        date.present? && date != zero_date && date >= cut_off_date
      end

      module_function :collection_resource,
                      :filter_data_by_refill_and_renew,
                      :filter_non_va_meds,
                      :sort_by
    end
  end
end
