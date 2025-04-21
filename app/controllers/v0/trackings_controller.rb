# frozen_string_literal: true

module V0
  class TrackingsController < MyHealth::RxController
    # This index action supports various parameters described below, all are optional
    # This comment can be removed once documentation is finalized
    # @param page - the paginated page to fetch
    # @param per_page - the number of items to fetch per page
    # @param sort - the attribute to sort on, negated for descending
    #        (ie: ?sort=shipped_date)
    def index
      resource = client.get_tracking_history_rx(params[:prescription_id])
      resource = resource.sort(params[:sort])
      resource = resource.paginate(**pagination_params)

      links = pagination_links(resource)
      options = { meta: resource.metadata, links: }
      render json: TrackingSerializer.new(resource.data, options)
    end
  end
end
