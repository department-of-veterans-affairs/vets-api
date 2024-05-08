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
        sort_orders = get_sort_order(sort_params)
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

      def get_sort_order(fields)
        fields.map do |field|
          field.to_s.start_with?('-')
        end
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
