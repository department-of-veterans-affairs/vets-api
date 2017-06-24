# frozen_string_literal: true

module V0
  module Preneeds
    class MilitaryRanksController < PreneedsController
      # We call authenticate_token because auth is optional on this endpoint.
      skip_before_action(:authenticate)

      def index
        # Some branches have no end_date, but api requires it just the same
        ::Preneeds::Validations.military_rank_for_branch_of_service(params)
        resource = client.get_military_rank_for_branch_of_service(params)

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: MilitaryRankSerializer
      end
    end
  end
end
