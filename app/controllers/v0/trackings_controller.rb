# frozen_string_literal: true
module V0
  class TrackingsController < RxController
    SORT_FIELDS   = %w(shipped_date).freeze
    SORT_TYPES    = (SORT_FIELDS + SORT_FIELDS.map { |field| "-#{field}" }).freeze
    DEFAULT_SORT  = '-shipped_date'

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
      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: TrackingSerializer,
             meta: resource.metadata
    end
  end
end
