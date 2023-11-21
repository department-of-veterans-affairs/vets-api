# frozen_string_literal: true

module Mobile
  module V0
    class DisabilityRatingController < ApplicationController
      before_action do
        if Flipper.enabled?(:mobile_lighthouse_disability_ratings, @current_user)
          authorize :lighthouse, :access?
        else
          authorize :evss, :access?
        end
      end

      def index
        response = if Flipper.enabled?(:mobile_lighthouse_disability_ratings, @current_user)
                     disability_rating_adapter.parse(lighthouse_disability_rating_proxy.get_rated_disabilities)
                   else
                     evss_disability_rating_proxy.get_disability_ratings
                   end

        render json: Mobile::V0::DisabilityRatingSerializer.new(response)
      end

      private

      def evss_disability_rating_proxy
        Mobile::V0::LegacyDisabilityRating::Proxy.new(@current_user)
      end

      def lighthouse_disability_rating_proxy
        Mobile::V0::DisabilityRating::Proxy.new(@current_user.icn)
      end

      def disability_rating_adapter
        Mobile::V0::Adapters::DisabilityRating.new
      end
    end
  end
end
