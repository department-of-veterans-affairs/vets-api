# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionsController < RxController
      include Filterable
      include MyHealth::PrescriptionHelper::Filtering
      include MyHealth::RxGroupingHelper
      # This index action supports various parameters described below, all are optional
      # This comment can be removed once documentation is finalized
      # @param refill_status - one refill status to filter on
      # @param page - the paginated page to fetch
      # @param per_page - the number of items to fetch per page
      # @param sort - the attribute to sort on, negated for descending, use sort[]= for multiple argument query params
      #        (ie: ?sort[]=refill_status&sort[]=-prescription_id)
      def index
        resource = collection_resource
        raw_data = resource.data.dup
        resource.records = resource_data_modifications(resource)

        filter_count = set_filter_metadata(resource.data, raw_data)
        resource = apply_filters(resource) if params[:filter].present?
        resource = params[:sort].is_a?(Array) ? sort_by(resource, params[:sort]) : resource.sort(params[:sort])
        resource.records = sort_prescriptions_with_pd_at_top(resource.data)
        is_using_pagination = params[:page].present? || params[:per_page].present?
        resource.records = params[:include_image].present? ? fetch_and_include_images(resource.data) : resource.data
        resource = resource.paginate(**pagination_params) if is_using_pagination
        options = { meta: resource.metadata.merge(filter_count) }
        options[:links] = pagination_links(resource) if is_using_pagination
        render json: MyHealth::V1::PrescriptionDetailsSerializer.new(resource.records, options)
      end

      def show
        id = params[:id].try(:to_i)
        resource = if Flipper.enabled?(:mhv_medications_display_grouping, current_user)
                     get_single_rx_from_grouped_list(collection_resource.data, id)
                   else
                     client.get_rx_details(id)
                   end
        raise Common::Exceptions::RecordNotFound, id if resource.blank?

        options = if Flipper.enabled?(:mhv_medications_display_grouping, current_user)
                    { meta: client.get_rx_details(id).metadata }
                  else
                    { meta: resource.metadata }
                  end
        render json: MyHealth::V1::PrescriptionDetailsSerializer.new(resource, options)
      end

      def refill
        client.post_refill_rx(params[:id])
        head :no_content
      end

      def filter_renewals(resource)
        resource.records = resource.data.select(&method(:renewable))
        resource.metadata = resource.metadata.merge({
                                                      'filter' => {
                                                        'disp_status' => {
                                                          'eq' => 'Active,Expired'
                                                        }
                                                      }
                                                    })
        resource
      end

      def refill_prescriptions
        ids = params[:ids]
        successful_ids = []
        failed_ids = []
        ids.each do |id|
          client.post_refill_rx(id)
          successful_ids << id
        rescue => e
          puts "Error refilling prescription with ID #{id}: #{e.message}"
          failed_ids << id
        end
        render json: { successful_ids:, failed_ids: }
      end

      def list_refillable_prescriptions
        resource = collection_resource
        resource.records = filter_data_by_refill_and_renew(resource.data)

        options = { meta: resource.metadata }
        render json: MyHealth::V1::PrescriptionDetailsSerializer.new(resource.data, options)
      end

      def get_prescription_image
        image_url = get_image_uri(params[:cmopNdcNumber])
        image_data = fetch_image(image_url)
        render json: { data: image_data }
      end

      private

      # rubocop:disable ThreadSafety/NewThread
      # New threads are joined at the end
      def fetch_and_include_images(data)
        threads = []
        data.each do |item|
          cmop_ndc_number = item.cmop_ndc_value
          if cmop_ndc_number.present?
            image_uri = get_image_uri(cmop_ndc_number)
            threads << Thread.new(item) do |thread_item|
              thread_item.prescription_image = fetch_image(image_uri)
            rescue => e
              puts "Error fetching image for NDC #{thread_item.cmop_ndc_number}: #{e.message}"
            end
          end
        end
        threads.each(&:join)
        data
      end
      # rubocop:enable ThreadSafety/NewThread

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

      def get_image_uri(cmop_ndc_number)
        folder_names = %w[1 2 3 4 5 6 7 8 9]
        folder_name = cmop_ndc_number ? cmop_ndc_number.gsub(/^0+(?!$)/, '')[0] : ''
        file_name = "NDC#{cmop_ndc_number}.jpg"
        folder_name = 'other' unless folder_names.include?(folder_name)
        image_root_uri = 'https://www.myhealth.va.gov/static/MILDrugImages/'
        "#{image_root_uri + folder_name}/#{file_name}"
      end

      def filter_params
        @filter_params ||= begin
          valid_filter_params = params.require(:filter).permit(PrescriptionDetails.filterable_params)
          raise Common::Exceptions::FilterNotAllowed, params[:filter] if valid_filter_params.empty?

          valid_filter_params
        end
      end

      def apply_filters(resource)
        resource.metadata[:filter] = {}
        disp_status = filter_params[:disp_status]

        if disp_status.present?
          if disp_status[:eq]&.downcase == 'active,expired'.downcase
            filter_renewals(resource)
          else
            filters = disp_status[:eq].split(',').map(&:strip).map(&:downcase)
            resource.records = resource.data.select { |item| filters.include?(item.disp_status.downcase) }
            resource.metadata[:filter][:dispStatus] = { eq: disp_status[:eq] }
          end
        end
        resource
      end

      def collection_resource
        case params[:refill_status]
        when nil
          client.get_all_rxs
        when 'active'
          client.get_active_rxs_with_details
        end
      end

      def resource_data_modifications(resource)
        display_grouping = Flipper.enabled?(:mhv_medications_display_grouping, current_user)
        display_pending_meds = Flipper.enabled?(:mhv_medications_display_pending_meds, current_user)
        # according to business logic filter for all medications is the only list that should contain PD meds
        resource.records = if params[:filter].blank? && display_pending_meds
                             resource.data.reject { |item| item.prescription_source.equal? 'PF' }
                           else
                             # TODO: remove this line when PF and PD are allowed on va.gov
                             resource.records = remove_pf_pd(resource.data)
                           end
        resource.records = group_prescriptions(resource.data) if display_grouping
        resource.records = filter_non_va_meds(resource.data)
      end

      def set_filter_metadata(list, non_modified_collection)
        {
          filter_count: {
            all_medications: group_prescriptions(non_modified_collection).length,
            active: count_active_medications(list),
            recently_requested: count_recently_requested_medications(list),
            renewal: list.select(&method(:renewable)).length,
            non_active: count_non_active_medications(list)
          }
        }
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

      def count_non_active_medications(list)
        non_active_statuses = %w[Discontinued Expired Transferred Unknown]
        list.select { |rx| non_active_statuses.include?(rx.disp_status) }.length
      end

      # TODO: remove once pf and pd are allowed on va.gov
      def remove_pf_pd(data)
        sources_to_remove_from_data = %w[PF PD]
        data.reject { |item| sources_to_remove_from_data.include?(item.prescription_source) }
      end

      def sort_prescriptions_with_pd_at_top(prescriptions)
        prescriptions.sort do |a, b|
          if a.prescription_source == 'PD' && b.prescription_source != 'PD'
            -1
          elsif a.prescription_source != 'PD' && b.prescription_source == 'PD'
            1
          else
            0
          end
        end
      end
    end
  end
end
