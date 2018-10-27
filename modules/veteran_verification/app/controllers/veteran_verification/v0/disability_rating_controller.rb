# frozen_string_literal: true

require_dependency 'veteran_verification/application_controller'

module VeteranVerification
  module V0
    class DisabilityRatingController < ApplicationController
      before_action { authorize :evss, :access? }
      before_action { permit_scopes %w[disability_rating.read] }

      def index
        response = service.get_rated_disabilities
        render json: response.rated_disabilities,
               each_serializer: VeteranVerification::DisabilityRatingSerializer
      end

      private

      def service
        EVSS::DisabilityCompensationForm::Service.new(auth_headers)
      end

      def auth_headers
        headers = EVSS::DisabilityCompensationAuthHeaders.new(@current_user)
        headers.add_headers(EVSS::AuthHeaders.new(@current_user).to_h)
      end
    end
  end
end
