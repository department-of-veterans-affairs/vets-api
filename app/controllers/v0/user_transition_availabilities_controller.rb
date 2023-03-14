# frozen_string_literal: true

module V0
  class UserTransitionAvailabilitiesController < ApplicationController
    def index
      availability = AcceptableVerifiedCredentialAdoptionService.new(@current_user).perform
      render json: availability
    rescue => e
      render json: { errors: e }, status: bad_request
    end
  end
end
