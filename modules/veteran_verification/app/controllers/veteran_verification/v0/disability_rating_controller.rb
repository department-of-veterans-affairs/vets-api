# frozen_string_literal: true

require_dependency 'veteran_verification/application_controller'
require_dependency 'notary'

module VeteranVerification
  module V0
    class DisabilityRatingController < ApplicationController
      include ActionController::MimeResponds

      def index
        disabilities_response = rating_service.get_rating(@current_user)
        serialized = ActiveModelSerializers::SerializableResource.new(
            disabilities_response,
            each_serializer: VeteranVerification::DisabilityRatingSerializer
        )

        respond_to do |format|
          format.json { render json: serialized.to_json }
        end
      end

      private

      def rating_service
        BGS::DisabilityRatingService.new
      end
    end
  end
end
