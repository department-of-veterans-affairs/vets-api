# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionsController < RxController
      include Filterable
      include MyHealth::PrescriptionsHelpers::Filtering
      include MyHealth::PrescriptionsHelpers::Imaging
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
        resource.data = filter_non_va_meds(resource.data)
        resource = if sorting_key_primary == 'prescription_name'
                     sort_by_prescription_name(resource)
                   elsif sorting_key_primary == '-dispensed_date'
                     last_refill_date_filter(resource)
                   else
                     resource.sort(params[:sort])
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

      def refill_prescriptions
        ids = params[:ids]
        begin
          ids.each do |id|
            client.post_refill_rx(id)
          end
        rescue => e
          puts "Error refilling prescription: #{e.message}"
        end
        head :no_content
      end

      def list_refillable_prescriptions
        resource = collection_resource
        resource.data = filter_data_by_refill_and_renew(resource.data)
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: PrescriptionDetailsSerializer,
               meta: resource.metadata
      end

      def get_prescription_image
        image_url = get_image_uri(params[:cmopNdcNumber])
        image_data = fetch_image(image_url)
        render json: { data: image_data }
      end
    end
  end
end
