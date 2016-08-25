module Rx
  module V1
    class TrackingsController < RxController
      SORT_FIELDS   = %w(prescription_id, shipped_date).freeze
      SORT_TYPES    = (SORT_FIELDS + SORT_FIELDS.map { |field| "-#{field}" }).freeze
      DEFAULT_SORT  = "shipped_date".freeze

      # This index action supports various parameters described below, all are optional
      # This comment can be removed once documentation is finalized
      # @param page - the paginated page to fetch
      # @param per_page - the number of items to fetch per page
      # @param sort - the attribute to sort on, negated for descending
      #        (ie: ?sort=shipped_date)
      def index
        resource = client.get_tracking_history_rx(params[:prescription_id])
        resource = resource.sort(params[:sort] || DEFAULT_SORT, allowed: SORT_TYPES)
        resource = resource.paginate(pagination_params)
        respond_with resource.data, serializer: CollectionSerializer,
                                    each_serializer: TrackingSerializer,
                                    meta: resource.metadata
      end
    end
  end
end
