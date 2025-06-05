# frozen_string_literal: true

module Mobile
  module V0
    class DisabilityRatingController < ApplicationController
      before_action { authorize :lighthouse, :access? }

      def index
        response = disability_rating_adapter.parse(lighthouse_disability_rating_proxy.get_rated_disabilities)

        render json: Mobile::V0::DisabilityRatingSerializer.new(response)
      end

      private

      def lighthouse_disability_rating_proxy
        Mobile::V0::DisabilityRating::Proxy.new(@current_user.icn)
      end

      def disability_rating_adapter
        Mobile::V0::Adapters::DisabilityRating.new
      end
    end
  end
end
