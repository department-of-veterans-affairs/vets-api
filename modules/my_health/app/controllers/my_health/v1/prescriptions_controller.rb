# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionsController < RxController
      include Filterable
      # This index action supports various parameters described below, all are optional
      # This comment can be removed once documentation is finalized
      # @param refill_status - one refill status to filter on
      # @param page - the paginated page to fetch
      # @param per_page - the number of items to fetch per page
      # @param sort - the attribute to sort on, negated for descending, use sort[]= for multiple argument query params
      #        (ie: ?sort[]=refill_status&sort[]=-prescription_id)
      def index
        resource = collection_resource
        resource = params[:filter].present? ? resource.find_by(filter_params) : resource
        sorting_key_primary = params[:sort]&.first
        if sorting_key_primary == 'prescription_name'
          sort_by_prescription_name(resource)
        elsif sorting_key_primary == '-dispensed_date'
          resource = last_refill_date_filter(resource)
        else
          resource = resource.sort(params[:sort])
        end
        is_using_pagination = params[:page].present? || params[:per_page].present?
        resource.data = params[:include_image].present? ? fetch_and_include_images(resource.data) : resource.data
        resource = is_using_pagination ? resource.paginate(**pagination_params) : resource
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: PrescriptionDetailsSerializer,
               meta: resource.metadata
      end

      def show
        id = params[:id].try(:to_i)
        resource = client.get_rx_details(id)
        raise Common::Exceptions::RecordNotFound, id if resource.blank?

        render json: resource,
               serializer: PrescriptionDetailsSerializer,
               meta: resource.metadata
      end

      def refill
        client.post_refill_rx(params[:id])
        head :no_content
      end

      def get_prescription_image
        image_url = get_image_uri(params[:cmopNdcNumber])
        image_data = fetch_image(image_url)
        render json: { data: image_data }
      end

      private

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
        image_root_uri = 'https://www.myhealth.va.gov/static/MILDrugImages/';
        "#{image_root_uri + folder_name}/#{file_name}"
      end

      def collection_resource
        case params[:refill_status]
        when nil
          client.get_all_rxs
        when 'active'
          client.get_active_rxs_with_details
        end
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
        resource.data = resource.data.sort_by do |item|
          sorting_key_primary = if item.disp_status == 'Active: Non-VA' && !item.prescription_name
                                  item.orderable_item
                                else
                                  item.prescription_name
                                end
          sorting_key_secondary = item.sorted_dispensed_date
          [sorting_key_primary, sorting_key_secondary]
        end
        sort_metadata = {
          'prescription_name' => 'ASC',
          'dispensed_date' => 'ASC'
        }
        resource.metadata = resource.metadata.merge('sort' => sort_metadata)
      end
    end
  end
end
