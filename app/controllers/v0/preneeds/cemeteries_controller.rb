# frozen_string_literal: true

module V0
  module Preneeds
    class CemeteriesController < PreneedsController
      def index
        resource = client.get_cemeteries
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: CemeterySerializer
      end
    end
  end
end
