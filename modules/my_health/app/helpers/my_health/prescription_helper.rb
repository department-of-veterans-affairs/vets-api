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
          dispensed_date = item[:sorted_dispensed_date]&.to_date || item[:dispensed_date]&.to_date
          next true if item.is_refillable
          next true if ['Active: On Hold', 'Active: Parked', 'Unknown'].include?(disp_status)
          next true if disp_status == 'Discontinued' && valid_date_within_six_months?(dispensed_date)
          next true if disp_status == 'Expired' && expired_date.present? && valid_date_within_six_months?(expired_date)
          if disp_status == 'Active' && (item[:refill_remaining].positive? || valid_date_within_six_months?(dispensed_date))
            next true
          end
          next true if ['Active: Submitted', 'Active: Refill in Process'].include?(disp_status) &&
                       item[:refill_remaining].zero? && valid_date_within_six_months?(dispensed_date)

          false
        end
      end

      private

      def valid_date_within_six_months?(date)
        six_months_from_today = Time.zone.today - 6.months
        zero_date = Date.new(0, 1, 1)
        date.present? && date != zero_date && date >= six_months_from_today
      end

      module_function :collection_resource,
                      :filter_data_by_refill_and_renew,
                      :filter_non_va_meds,
                      :last_refill_date_filter,
                      :sort_by_prescription_name
    end

    module Imaging
      def fetch_and_include_images(data)
        threads = []
        data.each do |item|
          cmop_ndc_number = get_cmop_value(item)
          if cmop_ndc_number.present?
            image_uri = get_image_uri(cmop_ndc_number)
            threads << Thread.new(item) do |thread_item|
              thread_item[:prescription_image] = fetch_image(image_uri)
            rescue => e
              puts "Error fetching image for NDC #{thread_item[:cmop_ndc_number]}: #{e.message}"
            end
          end
        end
        threads.each(&:join)
        data
      end

      def fetch_image(image_url)
        uri = URI.parse(image_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        if response.is_a?(Net::HTTPSuccess)
          image_data = response.body
          base64_image = Base64.strict_encode64(image_data)
          "data:#{response['content-type']};base64,#{base64_image}"
        end
      end

      def get_cmop_value(item)
        cmop_ndc_number = nil
        if item[:rx_rf_records].present? || item[:cmop_ndc_number].present?
          cmop_ndc_number = if item[:rx_rf_records]&.[](0)&.[](1)&.[](0)&.key?(:cmop_ndc_number)
                              item[:rx_rf_records][0][1][0][:cmop_ndc_number]
                            elsif item[:cmop_ndc_number].present?
                              item[:cmop_ndc_number]
                            end
        end
        cmop_ndc_number
      end

      def get_image_uri(cmop_ndc_number)
        folder_names = %w[1 2 3 4 5 6 7 8 9]
        folder_name = cmop_ndc_number ? cmop_ndc_number.gsub(/^0+(?!$)/, '')[0] : ''
        file_name = "NDC#{cmop_ndc_number}.jpg"
        folder_name = 'other' unless folder_names.include?(folder_name)
        image_root_uri = 'https://www.myhealth.va.gov/static/MILDrugImages/'
        "#{image_root_uri + folder_name}/#{file_name}"
      end

      module_function :fetch_and_include_images,
                      :fetch_image,
                      :get_cmop_value,
                      :get_image_uri
    end
  end
end
