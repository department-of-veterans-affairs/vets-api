# frozen_string_literal: true

module V0
  class BranchesOfServiceController < PreneedsController
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)

    def index
      resource = client.get_branches_of_service

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: BranchesOfServiceSerializer
    end
  end
end
