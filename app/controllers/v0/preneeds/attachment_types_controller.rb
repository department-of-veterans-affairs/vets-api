# frozen_string_literal: true

module V0
  module Preneeds
    class AttachmentTypesController < PreneedsController
      def index
        resource = client.get_attachment_types
        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: PreneedsAttachmentTypeSerializer
      end
    end
  end
end
