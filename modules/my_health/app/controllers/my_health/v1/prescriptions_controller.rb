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
        resource.data = filter_non_va_meds(resource.data)
        resource = if sorting_key_primary == 'prescription_name'
                     sort_by_prescription_name(resource)
                   elsif sorting_key_primary == '-dispensed_date'
                     last_refill_date_filter(resource)
                   else
                     resource.sort(params[:sort])
                   end
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
          sorting_key_primary = if item.disp_status == 'Active: Non-VA' && !item.prescription_name.nil?
                                  item.orderable_item
                                elsif !item.prescription_name.nil?
                                  item.prescription_name
                                else
                                  ''
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
    end
  end
end
