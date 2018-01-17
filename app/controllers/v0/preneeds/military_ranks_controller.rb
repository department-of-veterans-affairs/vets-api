# frozen_string_literal: true

module V0
  module Preneeds
    class MilitaryRanksController < PreneedsController
      def index
        rank_params = ::Preneeds::MilitaryRankInput.new(params)
        raise Common::Exceptions::ValidationErrors, rank_params unless rank_params.valid?

        resource = client.get_military_rank_for_branch_of_service(rank_params.to_h)
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: MilitaryRankSerializer
      end
    end
  end
end
