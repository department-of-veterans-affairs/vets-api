# frozen_string_literal: true
module V0
  class DisabilityRatingsController < ApplicationController
    skip_before_action :authenticate

    def show
      disability_rating = DisabilityRating.new(current_user.rating_record['disabilityRatingRecord'])
      render json: disability_rating,
             serializer: DisabilityRatingSerializer
    end

    private

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
