# frozen_string_literal: true

module V0
  module Preneeds
    class StatesController < PreneedsController
      def index
        resource = client.get_states
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: ::Preneeds::StateSerializer
      end
    end
  end
end
