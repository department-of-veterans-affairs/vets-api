# frozen_string_literal: true

module V0
  module Preneeds
    class DischargeTypesController < PreneedsController
      def index
        resource = client.get_discharge_types
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: DischargeTypeSerializer
      end
    end
  end
end
