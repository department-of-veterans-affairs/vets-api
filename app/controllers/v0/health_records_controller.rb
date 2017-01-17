# frozen_string_literal: true
module V0
  class HealthRecordsController < BBController
    def refresh
      resource = client.get_extract_status

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: ExtractStatusSerializer,
             meta: resource.metadata
    end
  end
end
