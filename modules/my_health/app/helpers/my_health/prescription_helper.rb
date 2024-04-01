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

      def last_refill_date_filter(resource)
        sorted_data = resource.data.sort_by { |r| r[:sorted_dispensed_date] }.reverse
        sort_metadata = {
          'dispensed_date' => 'DESC',
          'prescription_name' => 'ASC'
        }
        new_metadata = resource.metadata.merge('sort' => sort_metadata)
        Common::Collection.new(PrescriptionDetails, data: sorted_data, metadata: new_metadata)
      end

      def sort_by_prescription_name(resource)
        sorted_data = resource.data.sort_by do |item|
          sorting_key_primary = if item.disp_status == 'Active: Non-VA' && !item.prescription_name
                                  item.orderable_item
                                elsif !item.prescription_name.nil?
                                  item.prescription_name
                                else
                                  '~'
                                end
          sorting_key_secondary = item.sorted_dispensed_date
          [sorting_key_primary, sorting_key_secondary]
        end
        sort_metadata = {
          'prescription_name' => 'ASC',
          'dispensed_date' => 'ASC'
        }
        new_metadata = resource.metadata.merge('sort' => sort_metadata)
        Common::Collection.new(PrescriptionDetails, data: sorted_data, metadata: new_metadata)
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
                      :last_refill_date_filter,
                      :sort_by_prescription_name
    end
  end
end
