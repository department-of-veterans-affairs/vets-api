# frozen_string_literal: true

require 'lighthouse/veteran_verification/service'

module V0
  class RatedDisabilitiesController < ApplicationController
    service_tag 'disability-rating'
    before_action { authorize :lighthouse, :access? }

    def show
      response = service.get_rated_disabilities(@current_user.icn)

      # We only want active ratings
      if response.dig('data', 'attributes', 'individual_ratings')
        remove_inactive_ratings!(response['data']['attributes']['individual_ratings'])
      end

      render json: response
    end

    private

    def remove_inactive_ratings!(ratings)
      ratings.select! { |rating| active?(rating) }
    end

    def active?(rating)
      rating['rating_end_date'].nil?
    end

    def service
      @service ||= VeteranVerification::Service.new
    end
  end
end
