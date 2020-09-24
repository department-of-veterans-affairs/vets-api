# frozen_string_literal: true

module V0
  module Preneeds
    class BranchesOfServiceController < PreneedsController
      def index
        resource = client.get_branches_of_service

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: BranchesOfServiceSerializer
      end
    end
  end
end
