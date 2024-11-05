# frozen_string_literal: true

module V0
  class HealthRecordsController < BBController
    def refresh
      resource = client.get_extract_status

      options = { meta: resource.metadata }
      render json: ExtractStatusSerializer.new(resource.data, options)
    end

    def eligible_data_classes
      resource = client.get_eligible_data_classes

      options = { meta: resource.metadata, is_collection: false }
      render json: EligibleDataClassesSerializer.new(resource.data, options)
    end

    def create
      client.post_generate(params.permit(:from_date, :to_date, data_classes: []))

      head :accepted
    end
  end
end
