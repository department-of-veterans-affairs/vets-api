# frozen_string_literal: true

module V0
  class MilitaryRanksController < PreneedsController
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)

    def index
      # Some branches have no end_date, but api requires it just the same
      json_params = get_military_rank_for_branch_of_service_params

      Preneeds::Validations.get_military_rank_for_branch_of_service(json_params)
      resource = client.get_military_rank_for_branch_of_service(json_params)
      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: MilitaryRankSerializer
    end

    private

    def get_military_rank_for_branch_of_service_params
      {
        'branch_of_service' => params[:branch_of_service],
        'start_date' => params[:start_date],
        'end_date' => params[:end_date].blank? ? params[:start_date] : params[:end_date]
      }
    end
  end
end
