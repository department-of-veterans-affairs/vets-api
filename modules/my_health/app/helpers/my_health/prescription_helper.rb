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

      #STEPS FOR GROUPING MEDS

        # check if current med has any associated rxs by prescription_number whithin the list
        # group all associated rxs into an array

        # determine which grouped rx will be the main object that houses all the other objects
          #the most recent, which is the rx with the farthest letter from A so if prescription_numbers are 1234a, 5678b, 91011c, then the main rx will the the one that ends with c which is 91011c
        # add all other associated rxs to new field called grouped medications

        # if no associated rxs are found, add med to list with empty gouped meds field
        # check if current med has already been added, if so, then skip med and do not add to new list since its already on there

      def grouping_list(resource)
        grouped_list = Hash.new

        #method that returns rx with no suffix
        def rx_number_w_no_suffix(rx)
          rx_num = rx.attributes[:prescription_number]
          rx_num_no_suffix = rx_num.length > 6 ? rx_num[0..6] : rx_num
        end
        #method that gathers all the meds with the same prescription_number and puts them all into a list

        def group_and_sort_associated_rxs(list, prescription_number)
          associated_rxs = Array.new
          #for some reason, .select is throwing this error: ""undefined method `attributes' for an instance of Array""
          associated_rxs = list.data.attributes.select { |rx|
            if rx.attributes[:prescription_number].include? prescription_number
              rx
            end
          }

          #sort by suffix of prescription number. truncate the first 7 numbers and perform a sort on the letters
          # associated_rxs.sort_by[:prescription_number][0..-7].reverse
        end

        grouped_list = resource.map { |rx|
          prescription_number = rx_number_w_no_suffix(rx)
          grouped_and_sorted_list = group_and_sort_associated_rxs(resource, prescription_number)
          #sort list where rx without suffix is last and reverse alphabetical order where a is last and z is first in the list
          #make the most recent(first item on list) the head of the grouped medicaitons ie most_recent: {grouped_medications: [grouped_list]}
          #add group_rx_w_associated_rxs to new grouping list
          #dont forget to skip already added rxs and not add them to the list, since they are already a part of a grouped list within an rx
        }

        resource[:data] = resource.data.map { |rx|

          if rx[:prescription_id] == resource.data.first().attributes[:prescription_id]
            puts rx.attributes.to_s
          end

          #test to see if I can add anything to the grouped medications attribute
          puts rx.attributes[:grouped_medications]
          rx.attributes[:grouped_medications] = rx.attributes
        }

        resource
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
  end
end
