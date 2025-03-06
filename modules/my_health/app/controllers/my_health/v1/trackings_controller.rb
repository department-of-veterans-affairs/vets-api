# frozen_string_literal: true

module MyHealth
  module V1
    class TrackingsController < RxController
      # This index action supports various parameters described below, all are optional
      # This comment can be removed once documentation is finalized
      # @param page - the paginated page to fetch
      # @param per_page - the number of items to fetch per page
      # @param sort - the attribute to sort on, negated for descending
      #        (ie: ?sort=shipped_date)
      def index
        resource = client.get_tracking_history_rx(params[:prescription_id], x_api_key)
        resource = resource.sort(params[:sort])
        resource = resource.paginate(**pagination_params)

        links = pagination_links(resource)
        options = { meta: resource.metadata, links: }
        render json: TrackingSerializer.new(resource.data, options)
      end

      private

      def x_api_key
        { 'x-api-key' => Settings.mhv_mobile.x_api_key }
      end
    end
  end
end
