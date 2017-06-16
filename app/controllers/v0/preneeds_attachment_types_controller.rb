# frozen_string_literal: true

module V0
  class PreneedsAttachmentTypesController < PreneedsController
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)

    def index
      resource = client.get_attachment_types
      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: PreneedsAttachmentTypeSerializer
    end
  end
end
