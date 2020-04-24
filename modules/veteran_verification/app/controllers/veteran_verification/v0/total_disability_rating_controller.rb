# frozen_string_literal: true

require_dependency 'veteran_verification/application_controller'
require_dependency 'notary'

module VeteranVerification
  module V0
    class TotalDisabilityRatingController < ApplicationController
      include ActionController::MimeResponds

      def index
        rating = rating_service.get_rating(@current_user)

        respond_to do |format|
          format.json { render json: rating.to_json }
        end
      end

      private

      def rating_service
        BGS::TotalDisabilityRatingService.new
      end
    end
  end
end
