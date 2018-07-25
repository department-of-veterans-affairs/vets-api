# frozen_string_literal: true

module VeteranVerification
  module V0
    class DisabilityRatingController < ApplicationController
      before_action { authorize :evss, :access? }

      def index
        response = service.get_rated_disabilities
        render json: response.rated_disabilities,
               each_serializer: VeteranVerification::DisabilityRatingSerializer
      end

      private

      def service
        EVSS::DisabilityCompensationForm::Service.new(@current_user)
      end
    end
  end
end
