# frozen_string_literal: true

module V0
  class BurialStatesController < BurialsController
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)

    def index
      resource = client.get_states
      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: BurialStateSerializer
    end
  end
end
