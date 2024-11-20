# frozen_string_literal: true

require 'common/exceptions'

module MyHealth
  module PrescriptionHelper
    # rubocop:disable Metrics/MethodLength
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

          next true if item[:is_refillable]

          if item[:refill_remaining].to_i.zero?
            next true if disp_status.downcase == 'active'
            next true if disp_status.downcase == 'active: parked' && !item[:rx_rf_records].all?(&:empty?)
          end
          if disp_status == 'Expired' && expired_date.present? && valid_date_within_cut_off_date?(expired_date)
            next true
          end

          false
        end
      end

      def set_filter_metadata(list)
        {
          filter_count: {
            all_medications: list.length,
            active: count_active_medications(list),
            recently_requested: count_recently_requested_medications(list),
            renewal: count_renewals(list),
            non_active: count_non_active_medications(list)
          }
        }
      end

      private

      def valid_date_within_cut_off_date?(date)
        cut_off_date = Time.zone.today - 120.days
        zero_date = Date.new(0, 1, 1)
        date.present? && date != zero_date && date >= cut_off_date
      end

      def count_active_medications(list)
        active_statuses = [
          'Active', 'Active: Refill in Process', 'Active: Non-VA', 'Active: On hold',
          'Active: Parked', 'Active: Submitted'
        ]
        list.select { |rx| active_statuses.include?(rx.disp_status) }.length
      end

      def count_recently_requested_medications(list)
        recently_requested_statuses = ['Active: Refill in Process', 'Active: Submitted']
        list.select { |rx| recently_requested_statuses.include?(rx.disp_status) }.length
      end

      def count_renewals(list)
        list.select do |rx|
          is_expired = rx.disp_status == 'Expired'
          is_active_no_refills = rx.disp_status == 'Active' && rx.refill_remaining.zero?
          (is_expired || is_active_no_refills) && ['false'].include?(rx.is_refillable.to_s)
        end.length
      end

      def count_non_active_medications(list)
        non_active_statuses = %w[Discontinued Expired Transferred Unknown]
        list.select { |rx| non_active_statuses.include?(rx.disp_status) }.length
      end

      module_function :collection_resource,
                      :filter_data_by_refill_and_renew,
                      :filter_non_va_meds,
                      :sort_by,
                      :set_filter_metadata
    end
  end
end
