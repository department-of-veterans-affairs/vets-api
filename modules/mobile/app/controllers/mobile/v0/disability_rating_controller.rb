# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class DisabilityRatingController < ApplicationController
      def index
        response = rating_proxy.for_user
        render json: Mobile::V0::DisabilityRatingSerializer.new(response)
      end

      private

      def rating_proxy
        @rating_proxy ||= Mobile::V0::DisabilityRating::Proxy.new(@current_user)
      end
    end
  end
end
