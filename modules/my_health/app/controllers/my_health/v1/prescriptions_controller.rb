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
        resource = resource.sort(params[:sort])
        resource = last_refill_date_filter(resource) if params[0] == '-dispensed date'
        is_using_pagination = params[:page].present? || params[:per_page].present?
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

      private

      def collection_resource
        case params[:refill_status]
        when nil
          client.get_all_rxs
        when 'active'
          client.get_active_rxs_with_details
        end
      end

      def last_refill_date_filter(resource)
        resource = resource.sort_by do |x|
          x.rx_rf_records?.rf_record.find do |rf_record|
            rf_record[:dispensed_date].present?
          end.present? || x[:dispensed_date].present?
        end

        Collection.new(Prescription, data: resource, metadata:, errors:)
      end
    end
  end
end
