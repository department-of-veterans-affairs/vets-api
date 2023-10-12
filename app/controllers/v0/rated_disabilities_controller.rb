# frozen_string_literal: true

require 'lighthouse/veteran_verification/service'

module V0
  class RatedDisabilitiesController < ApplicationController
    before_action { authorize :lighthouse, :access? }

    def show
      response = service.get_rated_disabilities(@current_user.icn)
      individual_ratings = response.dig('data', 'attributes', 'individual_ratings')

      # We only want active ratings
      active_ratings = individual_ratings.select { |rating| active?(rating) }
      response['data']['attributes']['individual_ratings'] = active_ratings

      render json: response
    end

    private

    def active?(rating)
      rating['rating_end_date'].nil?
    end

    def service
      @service ||= VeteranVerification::Service.new
    end
  end
end
