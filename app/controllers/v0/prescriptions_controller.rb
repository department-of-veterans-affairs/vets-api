# frozen_string_literal: true

module V0
  class PrescriptionsController < RxController
    include Filterable

    # This index action supports various parameters described below, all are optional
    # This comment can be removed once documentation is finalized
    # @param refill_status - one refill status to filter on
    # @param page - the paginated page to fetch
    # @param per_page - the number of items to fetch per page
    # @param sort - the attribute to sort on, negated for descending
    #        (ie: ?sort=facility_name,-prescription_id)
    def index
      resource = collection_resource
      resource = resource.where(filter_params) if params[:filter].present?
      resource = resource.sort(params[:sort])
      resource = resource.paginate(**pagination_params)

      links = pagination_links(resource)
      options = { meta: resource.metadata, links: }
      render json: PrescriptionSerializer.new(resource.data, options)
    end

    def show
      id = params[:id].try(:to_i)
      resource = client.get_rx(id)
      raise Common::Exceptions::RecordNotFound, id if resource.blank?

      options = { meta: resource.metadata }
      render json: PrescriptionSerializer.new(resource, options)
    end

    def refill
      client.post_refill_rx(params[:id])
      head :no_content
    end

    private

    def collection_resource
      case params[:refill_status]
      when nil
        client.get_history_rxs
      when 'active'
        client.get_active_rxs
      end
    end
  end
end
