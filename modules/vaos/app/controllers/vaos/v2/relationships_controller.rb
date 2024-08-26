# frozen_string_literal: true

module VAOS
  module V2
    class RelationshipsController < VAOS::BaseController
      def index
        response = relationships_service.get_patient_relationships(
          relationships_params[:clinical_service_id],
          relationships_params[:facility_id]
        )

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(response, 'relationship')
        serialized.each { |relationship| relationship.delete(:id) }

        render json: { data: serialized }
      end

      private

      def relationships_service
        VAOS::V2::RelationshipsService.new(current_user)
      end

      def relationships_params
        params.permit(:clinical_service_id)
        params.permit(:facility_id)
        params
      end
    end
  end
end
