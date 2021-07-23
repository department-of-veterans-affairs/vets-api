# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class DisabilityRatingController < ApplicationController
      def index
        response = Mobile::V0::DisabilityRating.for_user(@current_user)
        render json: Mobile::V0::DisabilityRatingSerializer.new(response)
      end
    end
  end
end
