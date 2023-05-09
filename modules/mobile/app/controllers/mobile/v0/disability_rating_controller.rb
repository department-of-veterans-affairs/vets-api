# frozen_string_literal: true

module Mobile
  module V0
    class DisabilityRatingController < ApplicationController
      before_action { authorize :evss, :access? }
      def index
        response = rating_proxy.get_disability_ratings
        render json: Mobile::V0::DisabilityRatingSerializer.new(response)
      end

      private

      def rating_proxy
        Mobile::V0::DisabilityRating::Proxy.new(@current_user)
      end
    end
  end
end
