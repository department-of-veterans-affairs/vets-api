# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class DisabilityRatingController < ApplicationController
      def index
        response = VeteranVerification::DisabilityRating.for_user(@current_user)
        render json: VeteranVerification::DisabilityRatingSerializer.new(response)
      end
    end
  end
end
