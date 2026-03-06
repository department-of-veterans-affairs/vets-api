# frozen_string_literal: true

module MyHealth
  module V1
    class HealthRecordsController < BBController
      def refresh
        resource = client.get_extract_status

        render json: ExtractStatusSerializer.new(resource.data, { meta: resource.metadata })
      end

      def eligible_data_classes
        resource = client.get_eligible_data_classes

        render json: EligibleDataClassesSerializer.new(resource.data, { meta: resource.metadata })
      end

      def create
        client.post_generate(params.permit(:from_date, :to_date, data_classes: []))

        head :accepted
      end
    end
  end
end
